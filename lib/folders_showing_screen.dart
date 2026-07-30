import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fresh_player/theme/app_theme.dart';
import 'package:fresh_player/videos_show_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class FoldersShowingScreen extends StatefulWidget {
  const FoldersShowingScreen({super.key});

  @override
  State<FoldersShowingScreen> createState() => _FoldersShowingScreenState();
}

class _FoldersShowingScreenState extends State<FoldersShowingScreen> {
  Map<String, List<AssetEntity>> categorizedVideos = {};
  bool permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      permissionsCalling();
    }
  }

  Future<void> permissionsCalling() async {
    final bool permissionOk = await _requestPermissions();
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (permissionOk || ps.isAuth) {
      if (mounted) {
        setState(() {
          permissionsGranted = true;
        });
      }
      debugPrint("Permission is Granted");
      _loadVideos();
    } else {
      if (mounted) {
        setState(() {
          permissionsGranted = false;
        });
      }
      debugPrint("Permission is not Granted");
    }
  }

  Future<bool> _requestPermissions() async {
    AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
    if (build.version.sdkInt >= 33) {
      var videosStatus = await Permission.videos.request();
      var storageStatus = await Permission.storage.request();
      var manageStatus = await Permission.manageExternalStorage.request();
      return videosStatus.isGranted ||
          storageStatus.isGranted ||
          manageStatus.isGranted;
    } else if (build.version.sdkInt >= 30) {
      var manageExternalStorageStatus =
          await Permission.manageExternalStorage.request();
      var storageStatus = await Permission.storage.request();
      return manageExternalStorageStatus.isGranted || storageStatus.isGranted;
    } else {
      var storageStatus = await Permission.storage.request();
      return storageStatus.isGranted;
    }
  }

  String _cleanTitle(String rawTitle) {
    String t = rawTitle.toLowerCase().trim();
    for (var ext in [
      '.mp4',
      '.mkv',
      '.avi',
      '.mov',
      '.webm',
      '.3gp',
      '.flv',
      '.ts',
      '.m4v'
    ]) {
      if (t.endsWith(ext)) {
        t = t.substring(0, t.length - ext.length);
      }
    }
    return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<void> _loadVideos() async {
    // Query ONLY the master album containing all videos to avoid redundant album iterations
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: true,
      onlyAll: true,
    );

    if (albums.isEmpty) {
      if (mounted) {
        setState(() {
          categorizedVideos = {};
        });
      }
      return;
    }

    final AssetPathEntity masterAlbum = albums.first;
    final int totalAssets = await masterAlbum.assetCountAsync;

    final List<AssetEntity> videos = await masterAlbum.getAssetListRange(
      start: 0,
      end: totalAssets,
    );

    Map<String, List<AssetEntity>> tempCategorizedVideos = {
      'Downloads': [],
      'Camera': [],
      'WhatsApp': [],
      'Others': [],
    };

    Set<String> processedVideoIds = {};
    Set<String> processedFilePaths = {};
    Set<String> processedSizeDurationSigs = {};
    Set<String> processedTitleSigs = {};

    for (var video in videos) {
      // 1. Skip duplicate AssetEntity IDs
      if (processedVideoIds.contains(video.id)) continue;
      processedVideoIds.add(video.id);

      // 2. Resolve actual disk file for deep deduplication
      final File? file = await video.file;
      final String filePath = file?.path.toLowerCase() ?? '';

      // Skip non-existent files
      if (file != null && !await file.exists()) continue;

      // 3. Deduplicate by exact physical disk file path
      if (filePath.isNotEmpty) {
        if (processedFilePaths.contains(filePath)) continue;
        processedFilePaths.add(filePath);
      }

      // 4. Deduplicate by physical file byte length + video duration (catches duplicate files copied across folders)
      int fileSize = 0;
      if (file != null) {
        try {
          fileSize = await file.length();
        } catch (_) {}
      }

      final String sizeSig = '${fileSize}_${video.duration}';
      if (fileSize > 0 && processedSizeDurationSigs.contains(sizeSig)) {
        continue;
      }
      if (fileSize > 0) {
        processedSizeDurationSigs.add(sizeSig);
      }

      // 5. Deduplicate by cleaned title + duration signature
      final String rawTitle = video.title ?? (filePath.isNotEmpty ? filePath.split('/').last : '');
      final String cleanTitle = _cleanTitle(rawTitle);
      final String titleSig = '${cleanTitle}_${video.duration}';

      if (cleanTitle.isNotEmpty && processedTitleSigs.contains(titleSig)) {
        continue;
      }
      if (cleanTitle.isNotEmpty) {
        processedTitleSigs.add(titleSig);
      }

      // 6. Categorize based on physical path or relativePath
      final String pathToCheck = filePath.isNotEmpty
          ? filePath
          : (video.relativePath ?? '').toLowerCase();

      if (pathToCheck.contains('/dcim/') ||
          pathToCheck.contains('/camera/') ||
          pathToCheck.contains('camera')) {
        tempCategorizedVideos['Camera']?.add(video);
      } else if (pathToCheck.contains('whatsapp')) {
        tempCategorizedVideos['WhatsApp']?.add(video);
      } else {
        // Route PLAYit, Downloads, Telegram, Snaptube, IDM, Movies & all other downloaded videos into Downloads
        tempCategorizedVideos['Downloads']?.add(video);
      }
    }

    // Remove empty categories so only populated folders are shown
    tempCategorizedVideos.removeWhere((key, list) => list.isEmpty);

    if (mounted) {
      setState(() {
        categorizedVideos = tempCategorizedVideos;
      });
    }
  }

  IconData _getFolderIcon(String category) {
    switch (category.toLowerCase()) {
      case 'downloads':
        return Icons.download_rounded;
      case 'camera':
        return Icons.photo_camera_rounded;
      case 'whatsapp':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalVideos = categorizedVideos.values
        .fold(0, (sum, list) => sum + list.length);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentAqua.withOpacity(0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentAqua.withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'asset/images/logo.png',
                  height: 34,
                  width: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.play_circle_fill,
                    color: AppColors.primaryCoral,
                    size: 34,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, AppColors.accentAquaLight],
                  ).createShader(bounds),
                  child: const Text(
                    'Fresh Player',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // const Text(
                //   'Media Folders',
                //   style: TextStyle(
                //     fontSize: 12,
                //     color: AppColors.textSecondary,
                //     fontWeight: FontWeight.w400,
                //   ),
                // ),
              ],
            ),
          ],
        ),
      ),
      body: !permissionsGranted
          ? Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.cardDark,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.borderDark,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCoral.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.folder_special_rounded,
                        size: 48,
                        color: AppColors.primaryCoral,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Access Storage Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Fresh Player requires permission to scan your videos and organize them by folders.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: permissionsCalling,
                      icon: const Icon(Icons.security_rounded),
                      label: const Text("Grant Permission"),
                    ),
                  ],
                ),
              ),
            )
          : categorizedVideos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primaryCoral,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Scanning media folders...',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ListView(
                    children: [
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'CATEGORIES',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceDark,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.borderDark, width: 0.8),
                              ),
                              child: Text(
                                '$totalVideos Videos',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentAqua,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...categorizedVideos.entries.map((entry) {
                        final videos = entry.value;
                        final folderIcon = _getFolderIcon(entry.key);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideosShowScreen(
                                      downloadVideos: videos,
                                      title: entry.key,
                                    ),
                                  ),
                                );
                              },
                              child: Ink(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.cardDark,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.borderDark,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentAqua
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: AppColors.accentAqua
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Icon(
                                        folderIcon,
                                        size: 28,
                                        color: AppColors.accentAqua,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${videos.length} ${videos.length == 1 ? "video" : "videos"}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.surfaceDark,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: AppColors.accentAqua,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

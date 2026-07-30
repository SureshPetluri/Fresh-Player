import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:fresh_player/theme/app_theme.dart';
import 'package:fresh_player/video_play_screen.dart';
import 'package:photo_manager/photo_manager.dart';

class VideosShowScreen extends StatefulWidget {
  const VideosShowScreen(
      {super.key, required this.downloadVideos, required this.title});

  final List<AssetEntity> downloadVideos;
  final String title;

  @override
  State<VideosShowScreen> createState() => _VideosShowScreenState();
}

class _VideosShowScreenState extends State<VideosShowScreen> {
  List<AssetEntity> temporaryVideos = <AssetEntity>[];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    temporaryVideos = widget.downloadVideos;
    super.initState();
  }

  String convertSeconds(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void searchQuery(String query) {
    setState(() {
      temporaryVideos = widget.downloadVideos
          .where((element) =>
              (element.title ?? "").toUpperCase().contains(query.toUpperCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '${temporaryVideos.length} ${temporaryVideos.length == 1 ? "video" : "videos"} available',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: TextField(
              controller: searchController,
              onChanged: searchQuery,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: "Search videos...",
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.accentAqua,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          searchController.clear();
                          searchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: temporaryVideos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: AppColors.textMuted.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No videos found",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: temporaryVideos.length,
                    itemBuilder: (context, index) {
                      final video = temporaryVideos[index];
                      final title = video.title ?? 'Untitled Video';
                      final durationStr = convertSeconds(video.duration);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              File? videoFile = await video.file;
                              if (videoFile != null && context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPlayScreen(
                                      videoFile: videoFile,
                                      name: title,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Ink(
                              padding: const EdgeInsets.all(12),
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
                                  // Video Thumbnail container from AssetEntity
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 68,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceDark,
                                        borderRadius: BorderRadius.circular(12),
                                        // border: Border.all(
                                        //   color: AppColors.accentAqua
                                        //       .withValues(alpha: 0.3),
                                        // ),
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          FutureBuilder<Uint8List?>(
                                            future: video.thumbnailDataWithSize(
                                              const ThumbnailSize(200, 200),
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                      ConnectionState.done &&
                                                  snapshot.data != null) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Container(
                                                color: AppColors.surfaceDark,
                                                child: const Icon(
                                                  Icons
                                                      .play_circle_fill_rounded,
                                                  color: AppColors.primaryCoral,
                                                  size: 28,
                                                ),
                                              );
                                            },
                                          ),
                                          Container(
                                            color: Colors.black
                                                .withValues(alpha: 0.2),
                                          ),
                                          Center(
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryCoral
                                                    .withValues(alpha: 0.85),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.3),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.play_arrow_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              durationStr,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryCoral
                                            .withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AppColors.primaryCoral,
                                      ),
                                    ),
                                    onPressed: () async {
                                      File? videoFile = await video.file;
                                      if (videoFile != null) {
                                        await videoFile.delete();
                                        setState(() {
                                          temporaryVideos.removeAt(index);
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
  }

  String convertSeconds(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 15.0,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: widget.downloadVideos.map((video) {
            return ListTile(
              leading: const Icon(Icons.video_library),
              subtitle: InkWell(
                onTap: () async {
                  File? videoFile = await video.file;
                  if (videoFile != null) {
                  }
                },
                child: Text(video.title ?? 'No title'),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
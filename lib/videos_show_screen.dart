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
  List<AssetEntity> temporaryVideos = <AssetEntity>[];
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    temporaryVideos = widget.downloadVideos;
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

  searchQuery(String query) {
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
        elevation: 15.0,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: TextFormField(
              controller: searchController,
              onChanged: searchQuery,
              decoration: const InputDecoration(
                  isDense: true,
                  labelText: "Search Movie",
                  border: OutlineInputBorder()),
            ),
          ),
          ...temporaryVideos.map((video) {
            return ListTile(
              leading: const Icon(Icons.video_library),
              subtitle: InkWell(
                onTap: () async {
                  File? videoFile = await video.file;
                  if (videoFile != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayScreen(
                          videoFile: videoFile,
                          name: video.title ?? "",
                        ),
                      ),
                    );
                  }
                },
                child: Text(video.title ?? 'No title'),
              ),
            );
          }).toList(),
        ]),
      ),
    );
  }
}

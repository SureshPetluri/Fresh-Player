import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fresh_player/videos_show_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoScreen(),
    );
  }
}

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  Map<String, List<AssetEntity>> categorizedVideos = {};

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      permissionsCalling();
    }
  }

  bool permissionsGranted = false;

  Future<void> permissionsCalling() async {
    if (await _requestPermissions(Permission.manageExternalStorage)) {
      permissionsGranted =
          await _requestPermissions(Permission.manageExternalStorage);
      debugPrint("Permission is Granted");
      _loadVideos();
    } else {
      permissionsGranted = false;
      debugPrint("Permission is not Granted");
    }
  }

  Future<bool> _requestPermissions(Permission permission) async {
    AndroidDeviceInfo build = await DeviceInfoPlugin().androidInfo;
    if (build.version.sdkInt >= 30) {
      var manageExternalStorageStatus =
          await Permission.manageExternalStorage.request();
      var storageStatus = await Permission.storage.request();
      return manageExternalStorageStatus.isGranted || storageStatus.isGranted;
    } else {
      var storageStatus = await permission.request();
      return storageStatus.isGranted;
    }
  }

  Future<void> _loadVideos() async {
    final List<AssetPathEntity> albums =
        await PhotoManager.getAssetPathList(type: RequestType.video);

    Map<String, List<AssetEntity>> tempCategorizedVideos = {
      'Downloads': [],
      'Camera': [],
      'WhatsApp': [],
      'Others': [],
    };

    for (var album in albums) {
      final List<AssetEntity> videos =
          await album.getAssetListRange(start: 0, end: 100);
      for (var video in videos) {
        final path = video.relativePath ?? '';
        if (path.contains('download') &&
            !(tempCategorizedVideos['Downloads']?.contains(video) ?? false)) {
          tempCategorizedVideos['Downloads']?.add(video);
        } else if (path.contains('Camera') &&
            !(tempCategorizedVideos['Camera']?.contains(video) ?? false)) {
          tempCategorizedVideos['Camera']?.add(video);
        } else if (path.contains('WhatsApp') &&
            !(tempCategorizedVideos['WhatsApp']?.contains(video) ?? false)) {
          tempCategorizedVideos['WhatsApp']?.add(video);
        } else {
          tempCategorizedVideos['Others']?.add(video);
        }
      }
    }

    setState(() {
      categorizedVideos = tempCategorizedVideos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 15.0,
        title: const Text('Folders'),
      ),
      body: !(permissionsGranted)
          ? Center(
              child: ElevatedButton(
                onPressed: () {
                  permissionsCalling();
                },
                child: const Text("Request Permissions"),
              ),
            )
          : categorizedVideos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: ListView(
                    children: categorizedVideos.entries.map((entry) {
                      final videos = entry.value;
                      return Column(
                        children: [
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            radius: 0.4,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideosShowScreen(
                                      downloadVideos: videos, title: entry.key),
                                ),
                              );
                            },
                            child: Container(
                              width: MediaQuery.sizeOf(context).width,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 25, vertical: 5),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder,
                                    size: 50,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Text(entry.key),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}

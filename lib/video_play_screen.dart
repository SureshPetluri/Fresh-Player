import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayScreen extends StatefulWidget {
  const VideoPlayScreen({super.key, required this.videoFile});

  final File videoFile;

  @override
  State<VideoPlayScreen> createState() => _VideoPlayScreenState();
}

class _VideoPlayScreenState extends State<VideoPlayScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? videoController;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFullScreen = false;

  @override
  void initState() {
    videoPlayerInitialized(widget.videoFile);
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    // Initialize the Animation
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    // Optionally start the animation
    _controller.forward();

    super.initState();
  }

  void _seek(bool forward) {
    final currentPosition = videoController?.value.position;
    final newPosition = forward
        ? (currentPosition ?? const Duration(seconds: 1)) +
        const Duration(seconds: 10)
        : (currentPosition ?? const Duration(seconds: 1)) -
        const Duration(seconds: 10);
    videoController?.seekTo(newPosition);
  }

  void _handleDoubleTap(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < screenWidth / 2) {
      _seek(false); // Double-tap on the left side
    } else {
      _seek(true); // Double-tap on the right side
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    videoController?.dispose();
    super.dispose();
  }

  String start = "";
  String endTime = "";

  videoPlayerInitialized(File videoFile) async {
    videoController = VideoPlayerController.file(videoFile)
      ..addListener(() {
        if (videoController?.value.isInitialized ?? false) {
          start =
              videoController?.value.position.toString().split(".")[0] ?? "";
          // "${videoController?.value.position.inHours}:${videoController?.value.position.inMinutes}:${videoController?.value.position.inSeconds}";
          endTime =
              videoController?.value.duration.toString().split(".")[0] ?? "";
          setState(() {});
        }
        // if (videoController?.value.hasError ?? false) {
        // } else {
        //   startTime =
        //       videoController?.value.position.toString().split(".")[0] ?? "";
        //   endTime =
        //       videoController?.value.duration.toString().split(".")[0] ?? "";
        // }
        // notifyListeners();
      });
    await videoController?.initialize().onError((error, stackTrace) {});
    await videoController?.seekTo(Duration.zero);
    videoController?.play();
    setState(() {});
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeRight,
        DeviceOrientation.landscapeLeft,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    return PopScope(
      onPopInvoked: (e) {
        videoController?.pause();
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        appBar: orientation == Orientation.landscape
            ? null
            : AppBar(
          leading: IconButton(
            onPressed: () {
              Navigator.pop(context);
              videoController?.pause();
            },
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          title: const Text("Video Play"),
        ),
        body: Stack(
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: videoController?.value.aspectRatio ?? 16 / 7,
                child: Stack(
                  children: [
                    VideoPlayer(
                      videoController ??
                          VideoPlayerController.file(
                            File(""),
                          ),
                    ),
                    Positioned.fill(child: GestureDetector(
                      onDoubleTapDown: (details) {
                        _handleDoubleTap(details);
                        // Record the position of the double-tap
                      },
                    )),
                    Visibility(
                      visible: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Positioned(
                            bottom: 30.0,
                            right: 10.0,
                            left: 10.0,
                            child: VideoProgressIndicator(
                              videoController ??
                                  VideoPlayerController.file(File("")),
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                  backgroundColor: Colors.green,
                                  bufferedColor: Colors.grey,
                                  playedColor: Colors.blue),
                            ),
                          ),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  if (_controller.isCompleted) {
                                    _controller.reverse();
                                  } else {
                                    _controller.forward();
                                  }
                                  if (videoController?.value.isPlaying ??
                                      false) {
                                    videoController?.pause();
                                  } else {
                                    videoController?.play();
                                  }
                                },
                                child: AnimatedIcon(
                                  icon: AnimatedIcons.play_pause,
                                  progress: _animation,
                                  size: 25.0,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                  "$start/${videoController?.value.duration.toString().split(".")[0] ?? ""}"),
                              const Spacer(),
                              IconButton(
                                  onPressed: _toggleFullScreen,
                                  icon: Icon(_isFullScreen
                                      ? Icons.fullscreen_exit
                                      : Icons.fullscreen)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

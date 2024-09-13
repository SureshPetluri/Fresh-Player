import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class VideoPlayScreen extends StatefulWidget {
  const VideoPlayScreen(
      {super.key, required this.videoFile, required this.name});

  final File videoFile;
  final String name;

  @override
  State<VideoPlayScreen> createState() => _VideoPlayScreenState();
}

class _VideoPlayScreenState extends State<VideoPlayScreen>
    with TickerProviderStateMixin {
  VideoPlayerController? videoController;
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFullScreen = false;
  bool _isVideoReady = false;
  bool _showVideoDetails = false;
  late TransformationController _transformationController;
  double _currentScale = 1.0;
  int startTime = 0;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _transformationController = TransformationController();
  }

  void _initializeVideoPlayer() async {
    videoController = VideoPlayerController.file(widget.videoFile)
      ..addListener(() {
        if (videoController?.value.isInitialized ?? false) {
          startTime = videoController?.value.position.inSeconds ?? 0;
          setState(() {});
        }
        if (videoController?.value.isPlaying ?? false) {
          WakelockPlus.enable();
          _controller.reverse();
        } else {
          WakelockPlus.disable();
          _controller.forward();
        }
        setState(() {});
      });

    await videoController?.initialize();
    setState(() {
      _isVideoReady = true; // Video is now ready
    });
    videoController?.play();
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

  void _handleTap() {
    setState(() {
      _showVideoDetails = true;
      Future.delayed(const Duration(seconds: 3), () {
        _showVideoDetails = false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    videoController?.dispose();
    _transformationController.dispose();
    WakelockPlus.disable();
    super.dispose();
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
        backgroundColor: const Color(0xFF000000),
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
        body: Center(
          child: _isVideoReady
              ? (!_isFullScreen)
                  ? AspectRatio(
                      aspectRatio: videoController?.value.aspectRatio ?? 16 / 9,
                      child: buildVideoStack(),
                    )
                  : buildVideoStack()
              : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    Text("Buffering"),
                  ],
                ), // Show a loader until the video is ready
        ),
      ),
    );
  }

  Stack buildVideoStack() {
    return Stack(
      children: [
        InteractiveViewer(
            transformationController: _transformationController,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 1.0,
            maxScale: 3.0,
            onInteractionUpdate: (details) {
              setState(() {
                _currentScale = details.scale;
              });
            },
            child: VideoPlayer(videoController!)),
        GestureDetector(
          onDoubleTapDown: _handleDoubleTap,
          onTap: _handleTap,
        ),
        Visibility(
          visible: _showVideoDetails,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
             /* Slider(
                  value: (startTime) /
                      (videoController?.value.duration.inSeconds ?? 0.0),
                  onChanged: (e) {
                    startTime = e.ceil();
                    videoController?.seekTo(Duration(seconds: e.ceil()));
                    setState(() {});
                  }),*/
              VideoProgressIndicator(
                padding: const EdgeInsets.only(bottom: 4.0),
                videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  backgroundColor: Colors.green,
                  bufferedColor: Colors.grey,
                  playedColor: Colors.blue,
                ),
              ),
              Row(
                children: [
                  buildPlayPauseIconButton(25.0),
                  Text(
                    "${videoController?.value.position.toString().split(".")[0] ?? ""}/${videoController?.value.duration.toString().split(".")[0] ?? ""}",
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _toggleFullScreen,
                    icon: Icon(
                      _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Visibility(
            visible: (_showVideoDetails && _isFullScreen),
            child: ListTile(
              minVerticalPadding: 0.0,
              contentPadding: EdgeInsets.zero,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 34.0,
                  color: Color(0xFFFFFFFF),
                ),
                onPressed: () {
                  videoController?.pause();
                  _isFullScreen = false;
                  SystemChrome.setPreferredOrientations([
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ]);
                },
              ),
              title: Text(
                widget.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            )),
        Visibility(
          visible: _showVideoDetails,
          child: Center(child: buildPlayPauseIconButton(55.0)),
        ),
      ],
    );
  }

  IconButton buildPlayPauseIconButton(double size) {
    return IconButton(
      onPressed: () {
        if (_controller.isCompleted) {
          _controller.reverse();
        } else {
          _controller.forward();
        }
        if (videoController?.value.isPlaying ?? false) {
          videoController?.pause();
        } else {
          videoController?.play();
        }
      },
      icon: AnimatedIcon(
        icon: AnimatedIcons.pause_play,
        progress: _animation,
        size: size,
        color: Colors.blue,
      ),
    );
  }
}

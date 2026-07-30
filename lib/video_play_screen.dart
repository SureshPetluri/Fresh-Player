import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fresh_player/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isFullScreen = false;
  bool _isVideoReady = false;
  bool _showVideoDetails = false;
  late TransformationController _transformationController;
  int startTime = 0;
  Timer? _positionSaveTimer;
  Duration? _savedPosition;

  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  int _seekSecondsAccumulated = 0;
  Timer? _seekIndicatorTimer;

  @override
  void initState() {
    super.initState();
    _loadSavedPosition();

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _transformationController = TransformationController();
  }

  Future<void> _loadSavedPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final positionInMilliseconds = prefs.getInt(_getVideoKey());

    if (positionInMilliseconds != null) {
      setState(() {
        _savedPosition = Duration(milliseconds: positionInMilliseconds);
      });
    }

    _initializeVideoPlayer();
  }

  // Save the current position of the video
  Future<void> _saveVideoPosition() async {
    if (videoController != null && videoController!.value.isInitialized) {
      final position = videoController!.value.position;

      // Don't save if we're at the beginning or end
      if (position.inMilliseconds > 0 &&
          position.inMilliseconds <
              videoController!.value.duration.inMilliseconds - 5000) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_getVideoKey(), position.inMilliseconds);
      }
    }
  }

  // Generate a unique key for this video
  String _getVideoKey() {
    return 'video_position_${widget.videoFile.path.hashCode}';
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
    // If we have a saved position, seek to it
    if (_savedPosition != null && videoController != null) {
      if (_savedPosition!.inMilliseconds <
          (videoController!.value.duration.inMilliseconds - 5000)) {
        await videoController!.seekTo(_savedPosition!);
      }
    }
    setState(() {
      _isVideoReady = true; // Video is now ready
    });
    // Periodically save position
    _positionSaveTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted &&
          videoController != null &&
          videoController!.value.isPlaying) {
        _saveVideoPosition();
      }
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

    _seekIndicatorTimer?.cancel();
    setState(() {
      if (forward) {
        if (_showForwardIndicator) {
          _seekSecondsAccumulated += 10;
        } else {
          _seekSecondsAccumulated = 10;
        }
        _showForwardIndicator = true;
        _showBackwardIndicator = false;
      } else {
        if (_showBackwardIndicator) {
          _seekSecondsAccumulated += 10;
        } else {
          _seekSecondsAccumulated = 10;
        }
        _showBackwardIndicator = true;
        _showForwardIndicator = false;
      }
    });

    _seekIndicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showBackwardIndicator = false;
          _seekSecondsAccumulated = 0;
        });
      }
    });
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
      _showVideoDetails = !_showVideoDetails;
      if (_showVideoDetails) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showVideoDetails = false;
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _saveVideoPosition();
    _controller.dispose();
    videoController?.dispose();
    _transformationController.dispose();
    _positionSaveTimer?.cancel();
    _seekIndicatorTimer?.cancel();
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
      onPopInvokedWithResult: (e, _) {
        _saveVideoPosition();
        videoController?.pause();
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: orientation == Orientation.landscape
            ? null
            : AppBar(
                backgroundColor: AppColors.bgDark,
                elevation: 0,
                leading: IconButton(
                  onPressed: () {
                    _saveVideoPosition();
                    Navigator.pop(context);
                    videoController?.pause();
                  },
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.accentAqua,
                  ),
                ),
                title: Text(
                  widget.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
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
                    CircularProgressIndicator(
                      color: AppColors.primaryCoral,
                    ),
                    SizedBox(height: 16),
                    Text(
                      "Loading Video...",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Stack buildVideoStack() {
    return Stack(
      children: [
        InteractiveViewer(
          panEnabled: false,
          scaleEnabled: true,
          trackpadScrollCausesScale: true,
          panAxis: PanAxis.aligned,
          clipBehavior: Clip.antiAlias,
          transformationController: _transformationController,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 1.0,
          maxScale: 3.0,
          child: VideoPlayer(videoController!),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTapDown: _handleDoubleTap,
            onTap: _handleTap,
          ),
        ),
        // Backward 10s Indicator (Left half overlay)
        Positioned.fill(
          child: IgnorePointer(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _showBackwardIndicator ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: const BoxDecoration(
                        // color: AppColors.bgDark.withOpacity(0.7),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(120),
                          bottomRight: Radius.circular(120),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.fast_rewind_rounded,
                            size: 48,
                            color: AppColors.accentAqua,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "-${_seekSecondsAccumulated}s",
                            style: const TextStyle(
                              color: AppColors.accentAqua,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
        // Forward 10s Indicator (Right half overlay)
        Positioned.fill(
          child: IgnorePointer(
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _showForwardIndicator ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      decoration: BoxDecoration(
                        // color: AppColors.bgDark.withOpacity(0.7),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(120),
                          bottomLeft: Radius.circular(120),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.fast_forward_rounded,
                            size: 48,
                            color: AppColors.primaryCoral,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "+${_seekSecondsAccumulated}s",
                            style: const TextStyle(
                              color: AppColors.primaryCoral,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Bottom Controls Overlay
        Visibility(
          visible: _showVideoDetails,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    videoController!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      backgroundColor: AppColors.surfaceDark,
                      bufferedColor: AppColors.accentAqua.withOpacity(0.4),
                      playedColor: AppColors.primaryCoral,
                    ),
                  ),
                  Row(
                    children: [
                      buildPlayPauseIconButton(26.0),
                      const SizedBox(width: 8),
                      Text(
                        "${videoController?.value.position.toString().split(".")[0] ?? "0:00"} / ${videoController?.value.duration.toString().split(".")[0] ?? "0:00"}",
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _toggleFullScreen,
                        icon: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: AppColors.accentAqua,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Top Bar Overlay in FullScreen Mode
        Visibility(
          visible: (_showVideoDetails && _isFullScreen),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black87, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 24.0,
                      color: AppColors.accentAqua,
                    ),
                    onPressed: () {
                      _saveVideoPosition();
                      videoController?.pause();
                      _isFullScreen = false;
                      SystemChrome.setPreferredOrientations([
                        DeviceOrientation.portraitUp,
                        DeviceOrientation.portraitDown,
                      ]);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Center Play/Pause Floating Button Overlay
        Visibility(
          visible: _showVideoDetails,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentAqua.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentAqua.withOpacity(0.2),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: buildPlayPauseIconButton(52.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildPlayPauseIconButton(double size) {
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
      icon: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 1),
        builder: (context, double value, child) {
          return AnimatedIcon(
            icon: AnimatedIcons.play_pause,
            progress: AlwaysStoppedAnimation(value),
            size: size,
            color: AppColors.accentAqua,
          );
        },
      ),
    );
  }
}

import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fresh_player/theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'web_url_helper.dart';

class VideoPlayerForWeb extends StatefulWidget {
  const VideoPlayerForWeb({super.key});

  @override
  State<VideoPlayerForWeb> createState() => _VideoPlayerForWebState();
}

class _VideoPlayerForWebState extends State<VideoPlayerForWeb> {
  VideoPlayerController? _videoController;
  bool _isDragging = false;
  bool _isLoading = false;
  bool _isVideoReady = false;
  String _videoName = '';
  String? _errorMessage;

  // Controls visibility & auto-hide
  bool _showControls = true;
  Timer? _hideControlsTimer;

  // Video playback metrics
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  bool _isFullScreen = false;

  // Seek indicator feedback
  bool _showForwardIndicator = false;
  bool _showBackwardIndicator = false;
  int _seekSecondsAccumulated = 0;
  Timer? _seekIndicatorTimer;

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  void _resetHideControlsTimer() {
    _hideControlsTimer?.cancel();
    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && (_videoController?.value.isPlaying ?? false)) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _pickVideoFile() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;

        if (kIsWeb) {
          if (file.bytes != null && file.bytes!.isNotEmpty) {
            final blobUrl = createBlobUrl(file.bytes!, _getMimeType(name));
            await _initializeVideo(blobUrl, name);
          } else {
            setState(() {
              _errorMessage = 'Could not read file bytes.';
              _isLoading = false;
            });
          }
        } else {
          if (file.path != null && file.path!.isNotEmpty) {
            await _initializeVideo(file.path!, name);
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      setState(() {
        _errorMessage = 'Failed to open video file: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'ogg':
      case 'ogv':
        return 'video/ogg';
      case 'mov':
        return 'video/quicktime';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'video/mp4';
    }
  }

  Future<void> _handleDroppedFile(DropDoneDetails details) async {
    if (details.files.isEmpty) return;

    final droppedFile = details.files.first;
    final name = droppedFile.name;
    final path = droppedFile.path;

    debugPrint('Dropped file: $name, path: $path');

    if (!_isVideoFileName(name)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" does not appear to be a supported video file.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kIsWeb) {
        if (path.isNotEmpty && (path.startsWith('blob:') || path.startsWith('http'))) {
          await _initializeVideo(path, name);
        } else {
          final bytes = await droppedFile.readAsBytes();
          final blobUrl = createBlobUrl(bytes, _getMimeType(name));
          await _initializeVideo(blobUrl, name);
        }
      } else if (path.isNotEmpty) {
        await _initializeVideo(path, name);
      }
    } catch (e) {
      debugPrint('Error loading dropped file: $e');
      setState(() {
        _errorMessage = 'Failed to play dropped video: $e';
        _isLoading = false;
      });
    }
  }

  bool _isVideoFileName(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.mp4') ||
        ext.endsWith('.mkv') ||
        ext.endsWith('.webm') ||
        ext.endsWith('.mov') ||
        ext.endsWith('.avi') ||
        ext.endsWith('.m4v') ||
        ext.endsWith('.3gp') ||
        ext.endsWith('.flv') ||
        ext.endsWith('.ts');
  }

  Future<void> _initializeVideo(String urlOrPath, String name) async {
    // Dispose old controller
    await _videoController?.dispose();
    _videoController = null;

    setState(() {
      _isVideoReady = false;
      _isLoading = true;
      _videoName = name;
      _errorMessage = null;
    });

    try {
      final Uri videoUri = Uri.parse(urlOrPath);
      final controller = VideoPlayerController.networkUrl(videoUri);

      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

      await controller.initialize();
      await controller.setVolume(_isMuted ? 0.0 : _volume);
      await controller.setPlaybackSpeed(_playbackSpeed);

      if (mounted) {
        setState(() {
          _videoController = controller;
          _isVideoReady = true;
          _isLoading = false;
        });
        controller.play();
        _resetHideControlsTimer();
      }
    } catch (e) {
      debugPrint('Video initialization failed: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isVideoReady = false;
          _errorMessage = 'Unable to play video format. Please try an MP4 or WEBM file.';
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
      _resetHideControlsTimer();
    }
    setState(() {});
  }

  void _seek(bool forward) {
    if (_videoController == null || !_videoController!.value.isInitialized) return;
    final currentPos = _videoController!.value.position;
    const delta = Duration(seconds: 10);
    final targetPos = forward ? currentPos + delta : currentPos - delta;

    _videoController!.seekTo(targetPos);
    _resetHideControlsTimer();

    _seekIndicatorTimer?.cancel();
    setState(() {
      if (forward) {
        _seekSecondsAccumulated = _showForwardIndicator ? _seekSecondsAccumulated + 10 : 10;
        _showForwardIndicator = true;
        _showBackwardIndicator = false;
      } else {
        _seekSecondsAccumulated = _showBackwardIndicator ? _seekSecondsAccumulated + 10 : 10;
        _showBackwardIndicator = true;
        _showForwardIndicator = false;
      }
    });

    _seekIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _showForwardIndicator = false;
          _showBackwardIndicator = false;
          _seekSecondsAccumulated = 0;
        });
      }
    });
  }

  void _setVolume(double newVol) {
    setState(() {
      _volume = newVol;
      _isMuted = newVol == 0.0;
    });
    _videoController?.setVolume(_volume);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _videoController?.setVolume(_isMuted ? 0.0 : _volume);
  }

  void _setSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
    _videoController?.setPlaybackSpeed(speed);
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _loadSampleVideo() {
    // Public sample video for quick web demo testing
    const sampleUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    _initializeVideo(sampleUrl, 'Big Buck Bunny (Sample Video.mp4)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: DropTarget(
        onDragEntered: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onDragExited: (details) {
          setState(() {
            _isDragging = false;
          });
        },
        onDragDone: (details) async {
          setState(() {
            _isDragging = false;
          });
          await _handleDroppedFile(details);
        },
        child: Stack(
          children: [
            Column(
              children: [
                // Web Navigation Header
                _buildHeader(),

                // Main Content Body
                Expanded(
                  child: _isVideoReady && _videoController != null
                      ? _buildPlayerView()
                      : _buildDropZoneView(),
                ),
              ],
            ),

            // Drag overlay highlight when hovering a file over the screen
            if (_isDragging) _buildDragOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.cardDark,
        border: Border(
          bottom: BorderSide(color: AppColors.borderDark, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: AppColors.logoGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(
              'asset/images/logo.png',
              height: 24,
              width: 24,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'FRESH PLAYER',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryCoral.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.primaryCoral.withOpacity(0.5)),
            ),
            child: const Text(
              'WEB',
              style: TextStyle(
                color: AppColors.primaryCoral,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          if (_isVideoReady) ...[
            TextButton.icon(
              onPressed: _pickVideoFile,
              icon: const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.accentAqua),
              label: const Text(
                'Open Video',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.surfaceDark,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: AppColors.borderDark),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropZoneView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Drop Area Container
              InkWell(
                onTap: _pickVideoFile,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _isDragging ? AppColors.accentAqua : AppColors.primaryCoral.withOpacity(0.6),
                      width: _isDragging ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryCoral.withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Animated / Icon Container
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceDark,
                          border: Border.all(
                            color: AppColors.accentAqua.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.cloud_upload_rounded,
                          size: 56,
                          color: AppColors.accentAqua,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Drag & Drop your video here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'or click to browse local video files',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 28),
                      ElevatedButton.icon(
                        onPressed: _pickVideoFile,
                        icon: const Icon(Icons.video_file_rounded, size: 22),
                        label: const Text('Open Video File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryCoral,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                      if (_isLoading) ...[
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(color: AppColors.primaryCoral),
                        const SizedBox(height: 12),
                        const Text(
                          'Loading video...',
                          style: TextStyle(color: AppColors.accentAqua, fontSize: 14),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Supported formats row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Supported Formats:',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: ['MP4', 'WEBM', 'MKV', 'MOV', 'AVI'].map((ext) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: Text(
                          ext,
                          style: const TextStyle(
                            color: AppColors.accentAquaLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Quick sample video option
              OutlinedButton.icon(
                onPressed: _loadSampleVideo,
                icon: const Icon(Icons.play_circle_fill_rounded, color: AppColors.accentAqua, size: 18),
                label: const Text('Try Sample Video'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentAqua,
                  side: const BorderSide(color: AppColors.borderDark),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerView() {
    final controller = _videoController!;
    final value = controller.value;
    final position = value.position;
    final duration = value.duration;

    return MouseRegion(
      onHover: (_) => _resetHideControlsTimer(),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
          if (_showControls) {
            _resetHideControlsTimer();
          }
        },
        child: Container(
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video Player Display
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
                  child: VideoPlayer(controller),
                ),
              ),

              // Seek overlays (+10s / -10s)
              if (_showForwardIndicator) _buildSeekIndicator(isForward: true),
              if (_showBackwardIndicator) _buildSeekIndicator(isForward: false),

              // Gesture detection for double tap seek & play pause
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seek(false),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: _togglePlayPause,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onDoubleTap: () => _seek(true),
                    ),
                  ),
                ],
              ),

              // Top Title Overlay Bar
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _videoController?.pause();
                              _isVideoReady = false;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _videoName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.folder_open, color: AppColors.accentAqua),
                          tooltip: 'Open Another Video',
                          onPressed: _pickVideoFile,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Play/Pause Big Center Button when controls visible
              if (_showControls && !value.isPlaying)
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryCoral.withOpacity(0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCoral.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),

              // Bottom Controls Overlay Bar
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress slider & buffer
                        Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: AppColors.primaryCoral,
                                  inactiveTrackColor: Colors.white.withOpacity(0.3),
                                  thumbColor: AppColors.primaryCoral,
                                  overlayColor: AppColors.primaryCoral.withOpacity(0.2),
                                ),
                                child: Slider(
                                  value: position.inMilliseconds.toDouble().clamp(
                                        0.0,
                                        duration.inMilliseconds.toDouble() > 0
                                            ? duration.inMilliseconds.toDouble()
                                            : 1.0,
                                      ),
                                  max: duration.inMilliseconds.toDouble() > 0
                                      ? duration.inMilliseconds.toDouble()
                                      : 1.0,
                                  onChanged: (val) {
                                    controller.seekTo(Duration(milliseconds: val.toInt()));
                                    _resetHideControlsTimer();
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // Action Buttons Bar
                        Row(
                          children: [
                            // Play/Pause
                            IconButton(
                              icon: Icon(
                                value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: _togglePlayPause,
                            ),

                            // Seek Rewind
                            IconButton(
                              icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 24),
                              onPressed: () => _seek(false),
                            ),

                            // Seek Forward
                            IconButton(
                              icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 24),
                              onPressed: () => _seek(true),
                            ),

                            const SizedBox(width: 8),

                            // Volume
                            IconButton(
                              icon: Icon(
                                _isMuted || _volume == 0
                                    ? Icons.volume_off_rounded
                                    : Icons.volume_up_rounded,
                                color: AppColors.accentAqua,
                                size: 22,
                              ),
                              onPressed: _toggleMute,
                            ),
                            SizedBox(
                              width: 90,
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                  activeTrackColor: AppColors.accentAqua,
                                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                                  thumbColor: AppColors.accentAqua,
                                ),
                                child: Slider(
                                  value: _isMuted ? 0.0 : _volume,
                                  onChanged: _setVolume,
                                ),
                              ),
                            ),

                            const Spacer(),

                            // Speed Selector
                            PopupMenuButton<double>(
                              initialValue: _playbackSpeed,
                              tooltip: 'Playback Speed',
                              onSelected: _setSpeed,
                              color: AppColors.cardDark,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceDark,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderDark),
                                ),
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              itemBuilder: (context) => [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
                                return PopupMenuItem<double>(
                                  value: speed,
                                  child: Text(
                                    '${speed}x',
                                    style: TextStyle(
                                      color: _playbackSpeed == speed
                                          ? AppColors.primaryCoral
                                          : AppColors.textPrimary,
                                      fontWeight: _playbackSpeed == speed
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                            const SizedBox(width: 12),

                            // Fullscreen toggle
                            IconButton(
                              icon: Icon(
                                _isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                              onPressed: _toggleFullScreen,
                            ),
                          ],
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
    );
  }

  Widget _buildSeekIndicator({required bool isForward}) {
    return Align(
      alignment: isForward ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: AppColors.accentAqua,
              size: 36,
            ),
            const SizedBox(height: 4),
            Text(
              '${isForward ? '+' : '-'}$_seekSecondsAccumulated s',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragOverlay() {
    return Container(
      color: AppColors.bgDark.withOpacity(0.92),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.accentAqua, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentAqua.withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_download_rounded,
                size: 72,
                color: AppColors.accentAqua,
              ),
              SizedBox(height: 20),
              Text(
                'Drop Video to Play',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Release mouse to load this video file immediately',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

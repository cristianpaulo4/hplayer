import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/conversion_dialog.dart';

class PlayerScreen extends StatefulWidget {
  final String? initialFilePath;

  const PlayerScreen({super.key, this.initialFilePath});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  final FocusNode _focusNode = FocusNode();
  final FocusNode _videoFocusNode = FocusNode(canRequestFocus: false);
  bool showControls = true;
  Timer? _hideTimer;
  String? currentFilePath;
  bool isMuted = false;
  double lastVolume = 100.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilePath != null) {
      _openFile(widget.initialFilePath!);
    }
    _startHideTimer();
  }

  @override
  void dispose() {
    player.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => showControls = false);
      }
    });
  }

  void _onMouseMove() {
    if (!showControls) {
      setState(() => showControls = true);
    }
    _startHideTimer();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mkv', 'avi', 'mov', 'hevc', 'h265'],
    );

    if (result != null && result.files.single.path != null) {
      _openFile(result.files.single.path!);
    }
  }

  void _openFile(String path) {
    setState(() {
      currentFilePath = path;
    });
    player.open(Media(path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.space) {
              if (player.state.playing) {
                player.pause();
              } else {
                player.play();
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              player.seek(player.state.position - const Duration(seconds: 10));
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              player.seek(player.state.position + const Duration(seconds: 10));
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.keyF) {
              _toggleFullscreen();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: showControls ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onExit: (_) => setState(() => showControls = false),
          child: Listener(
            onPointerHover: (_) => _onMouseMove(),
            onPointerMove: (_) => _onMouseMove(),
            child: Stack(
          children: [
            // Video Player
            GestureDetector(
              onDoubleTap: () => _toggleFullscreen(),
              onTap: () {
                _focusNode.requestFocus();
                setState(() => showControls = !showControls);
              },
              child: Center(
                child: Video(
                  controller: controller,
                  fill: Colors.black,
                  controls: NoVideoControls,
                  focusNode: _videoFocusNode,
                ),
              ),
            ),

            // Top Bar
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top: showControls ? 0 : -100,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.srcOver),
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.folder_open, color: Colors.white),
                            onPressed: _pickFile,
                            tooltip: 'Abrir Arquivo',
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HPlayer',
                                style: TextStyle(
                                  color: Colors.deepPurpleAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Text(
                                currentFilePath != null
                                    ? currentFilePath!.split(Platform.pathSeparator).last
                                    : 'Pronto para reproduzir',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Controls
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: showControls ? 0 : -160,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.srcOver),
                  child: _buildBottomControls(),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek Bar
          StreamBuilder<Duration>(
            stream: player.stream.position,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              return StreamBuilder<Duration>(
                stream: player.stream.duration,
                builder: (context, snapshot) {
                  final duration = snapshot.data ?? Duration.zero;
                  return Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: Colors.deepPurpleAccent,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.deepPurpleAccent,
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(
                            0.0,
                            duration.inMilliseconds.toDouble() > 0
                                ? duration.inMilliseconds.toDouble()
                                : (position.inMilliseconds.toDouble() > 0
                                    ? position.inMilliseconds.toDouble()
                                    : 1.0),
                          ),
                          max: duration.inMilliseconds.toDouble() > 0
                              ? duration.inMilliseconds.toDouble()
                              : (position.inMilliseconds.toDouble() > 0
                                  ? position.inMilliseconds.toDouble()
                                  : 1.0),
                          onChanged: (value) {
                            player.seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            Text(_formatDuration(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 10),

          // Control Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Stop
              IconButton(
                icon: const Icon(Icons.stop, color: Colors.white70),
                onPressed: () async {
                  await player.pause();
                  await player.seek(Duration.zero);
                },
                tooltip: 'Parar',
              ),
              const SizedBox(width: 10),
              // Backward 10s
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white),
                onPressed: () {
                  final pos = player.state.position;
                  player.seek(pos - const Duration(seconds: 10));
                },
                tooltip: 'Voltar 10s',
              ),
              const SizedBox(width: 10),
              // Play/Pause
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snapshot) {
                  final playing = snapshot.data ?? false;
                  return IconButton(
                    iconSize: 54,
                    icon: Icon(
                      playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      if (playing) {
                        player.pause();
                      } else {
                        player.play();
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 10),
              // Forward 10s
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white),
                onPressed: () {
                  final pos = player.state.position;
                  player.seek(pos + const Duration(seconds: 10));
                },
                tooltip: 'Avançar 10s',
              ),
              const Spacer(),
              // Volume & Mute
              IconButton(
                icon: Icon(
                  isMuted || player.state.volume == 0
                      ? Icons.volume_off
                      : Icons.volume_up,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: _toggleMute,
              ),
              SizedBox(
                width: 120,
                child: StreamBuilder<double>(
                  stream: player.stream.volume,
                  builder: (context, snapshot) {
                    final volume = snapshot.data ?? 100.0;
                    return Slider(
                      value: volume,
                      max: 100.0,
                      onChanged: (value) {
                        player.setVolume(value);
                        if (value > 0) setState(() => isMuted = false);
                      },
                      activeColor: Colors.white,
                      inactiveColor: Colors.white24,
                    );
                  },
                ),
              ),
              const Spacer(),
              // Fullscreen
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white70),
                onPressed: _toggleFullscreen,
                tooltip: 'Tela Cheia',
              ),
              const SizedBox(width: 10),
              // Convert Button
              ElevatedButton.icon(
                onPressed: currentFilePath != null
                    ? () => _showConversionDialog()
                    : null,
                icon: const Icon(Icons.transform),
                label: const Text('Converter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showConversionDialog() {
    if (currentFilePath == null) return;
    showDialog(
      context: context,
      builder: (context) => ConversionDialog(filePath: currentFilePath!),
    );
  }

  void _toggleMute() {
    if (isMuted) {
      player.setVolume(lastVolume);
    } else {
      lastVolume = player.state.volume;
      player.setVolume(0);
    }
    setState(() {
      isMuted = !isMuted;
    });
  }

  void _toggleFullscreen() async {
    bool isFullScreen = await windowManager.isFullScreen();
    if (isFullScreen) {
      await windowManager.setFullScreen(false);
    } else {
      await windowManager.setFullScreen(true);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

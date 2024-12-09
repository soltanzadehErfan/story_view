import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  final String url;

  File? videoFile;

  final Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (videoFile != null) {
      state = LoadState.success;
      onComplete();
      return;
    }

    final fileStream = DefaultCacheManager()
        .getFileStream(url, headers: requestHeaders as Map<String, String>?);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (videoFile == null) {
          state = LoadState.success;
          videoFile = fileResponse.file;
          onComplete();
        }
      }
    }).onError((error) {
      state = LoadState.failure;
      onComplete();
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final int? quarterTurns;
  final bool? isRotated;

  StoryVideo(
    this.videoLoader, {
    Key? key,
    this.storyController,
    this.loadingWidget,
    this.errorWidget,
    this.width,
    this.height,
    this.quarterTurns,
    this.isRotated,
  }) : super(key: key ?? UniqueKey());

  static StoryVideo url(
    String url, {
    StoryController? controller,
    Map<String, dynamic>? requestHeaders,
    Key? key,
    Widget? loadingWidget,
    Widget? errorWidget,
    double? width,
    double? height,
    int? quarterTurns,
    bool? isRotated,
  }) {
    return StoryVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      width: width,
      height: height,
      quarterTurns: quarterTurns,
      isRotated: isRotated,
    );
  }

  @override
  State<StatefulWidget> createState() => StoryVideoState();
}

class StoryVideoState extends State<StoryVideo> {
  Player? _player;
  StreamSubscription? _playbackSubscription;

  @override
  void initState() {
    super.initState();

    widget.storyController?.pause();
    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        _initializePlayer();
      } else {
        setState(() {}); // Update UI for error state
      }
    });
  }

  Future<void> _initializePlayer() async {
    try {
      _player = Player();
      await _player!.open(Media(widget.videoLoader.url));
      setState(() {});
      widget.storyController?.play();

      _playbackSubscription =
          widget.storyController?.playbackNotifier.listen((playbackState) {
        if (playbackState == PlaybackState.pause) {
          _player?.pause();
        } else if (playbackState == PlaybackState.play) {
          _player?.play();
        }
      });
    } catch (e) {
      setState(() {
        widget.videoLoader.state = LoadState.failure;
      });
    }
  }

  Widget _buildContentView() {
    if (widget.videoLoader.state == LoadState.success && _player != null) {
      final content = Center(
        child: AspectRatio(
          aspectRatio: 16 / 9, // Adjust as needed
          child: Video(controller: VideoController(_player!)),
        ),
      );

      return widget.isRotated == true
          ? RotatedBox(
              quarterTurns: widget.quarterTurns ?? 0,
              child: content,
            )
          : content;
    }

    if (widget.videoLoader.state == LoadState.loading) {
      return Center(
        child: widget.loadingWidget ??
            SizedBox(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
      );
    }

    return Center(
      child: widget.errorWidget ??
          Text(
            "Media failed to load.",
            style: const TextStyle(color: Colors.white),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildContentView(),
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    _playbackSubscription?.cancel();
    super.dispose();
  }
}

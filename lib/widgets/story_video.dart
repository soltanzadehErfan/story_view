import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:better_player/better_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  String url;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream = DefaultCacheManager().getFileStream(this.url,
        headers: this.requestHeaders as Map<String, String>?);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
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
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  StreamSubscription? _streamSubscription;

  BetterPlayerController? betterPlayerController;

  @override
  void initState() {
    super.initState();

    widget.storyController!.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        final betterPlayerConfiguration = BetterPlayerConfiguration(
          fit: BoxFit.contain,
          autoPlay: false,
          looping: false,
        );
        final betterPlayerDataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          widget.videoLoader.url,
          drmConfiguration: BetterPlayerDrmConfiguration(),
        );

        betterPlayerController =
            BetterPlayerController(betterPlayerConfiguration)
              ..setupDataSource(betterPlayerDataSource);

        if (widget.storyController != null) {
          _streamSubscription =
              widget.storyController!.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              betterPlayerController!.pause();
            } else {
              betterPlayerController!.play();
            }
          });
        }

        setState(() {});
        widget.storyController!.play();
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success &&
        betterPlayerController != null) {
      if (Platform.isAndroid) {
        if (widget.isRotated == true) {
          return RotatedBox(
            quarterTurns: widget.quarterTurns ?? 0,
            child: Center(
              child: BetterPlayer(controller: betterPlayerController!),
            ),
          );
        } else {
          return Center(
            child: BetterPlayer(controller: betterPlayerController!),
          );
        }
      } else {
        if (widget.isRotated == true) {
          return RotatedBox(
            quarterTurns: widget.quarterTurns ?? 0,
            child: Center(
              child: BetterPlayer(controller: betterPlayerController!),
            ),
          );
        } else {
          return Center(
            child: BetterPlayer(controller: betterPlayerController!),
          );
        }
      }
    }

    return widget.videoLoader.state == LoadState.loading
        ? Center(
            child: widget.loadingWidget ??
                Container(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
          )
        : Center(
            child: widget.errorWidget ??
                Text(
                  "Media failed to load.",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: getContentView(),
    );
  }

  @override
  void dispose() {
    betterPlayerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}

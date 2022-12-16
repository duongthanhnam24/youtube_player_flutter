// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

import '../enums/player_state.dart';
import '../utils/youtube_meta_data.dart';
import '../utils/youtube_player_controller.dart';
import 'adaptive_webview_controller.dart';

/// A raw youtube player widget which interacts with the underlying webview inorder to play YouTube videos.
///
/// Use [YoutubePlayer] instead.
class RawYoutubePlayer extends StatefulWidget {
  /// Sets [Key] as an identification to underlying web view associated to the player.
  final Key? key;

  /// {@macro youtube_player_flutter.onEnded}
  final void Function(YoutubeMetaData metaData)? onEnded;

  /// Creates a [RawYoutubePlayer] widget.
  RawYoutubePlayer({
    this.key,
    this.onEnded,
  });

  @override
  _RawYoutubePlayerState createState() => _RawYoutubePlayerState();
}

class _RawYoutubePlayerState extends State<RawYoutubePlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController? controller;
  final webviewController = WebviewController();
  PlayerState? _cachedPlayerState;
  bool _isPlayerReady = false;
  bool _onLoadStopCalled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    
    if (Platform.isWindows) initPlatformState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  Future<void> initPlatformState() async {
    await webviewController.initialize();
    await webviewController.setBackgroundColor(Colors.transparent);
    await webviewController.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
    webviewController.webMessage.listen((event) {
      final args = event['arg'] ?? [] ;
      switch (event['event']) {
        case 'Ready':
          _onReady(args);
          break;
        case 'StateChange':
          _onStateChange(args);
          break;
        case 'PlaybackQualityChange':
          _onPlaybackQualityChange(args);
          break;
        case 'PlaybackRateChange':
          _onPlaybackRateChange(args);
          break;
        case 'Errors':
          _onErrors(args);
          break;
        case 'VideoData':
          _onVideoData(args);
          break;
        case 'VideoTime':
          _onVideoTime(args);
          break;
      }
    });

    await webviewController.loadStringContent(player);
    controller!.updateValue(
      controller!.value.copyWith(webViewController: AdaptiveWebviewController(webviewController)),
    );
    _onLoadStopCalled = true;
    if (_isPlayerReady) {
      controller!.updateValue(
        controller!.value.copyWith(isReady: true),
      );
    }

    if (!mounted) return;
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_cachedPlayerState != null &&
            _cachedPlayerState == PlayerState.playing) {
          controller?.play();
        }
        break;
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.paused:
        _cachedPlayerState = controller!.value.playerState;
        controller?.pause();
        break;
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    controller = YoutubePlayerController.of(context);
    if (Platform.isAndroid || Platform.isIOS) return buildMobile(context);
    if (Platform.isWindows) return buildWindows(context);
    throw UnsupportedError('UnsupportedError');
  }

  Widget buildMobile(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: InAppWebView(
        key: widget.key,
        initialData: InAppWebViewInitialData(
          data: player,
          baseUrl: Uri.parse('https://www.youtube.com'),
          encoding: 'utf-8',
          mimeType: 'text/html',
        ),
        initialOptions: InAppWebViewGroupOptions(
          crossPlatform: InAppWebViewOptions(
            userAgent: userAgent,
            mediaPlaybackRequiresUserGesture: false,
            transparentBackground: true,
            disableContextMenu: true,
            supportZoom: false,
            disableHorizontalScroll: false,
            disableVerticalScroll: false,
            useShouldOverrideUrlLoading: true,
          ),
          ios: IOSInAppWebViewOptions(
            allowsInlineMediaPlayback: true,
            allowsAirPlayForMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
          ),
          android: AndroidInAppWebViewOptions(
            useWideViewPort: false,
            useHybridComposition: controller!.flags.useHybridComposition,
          ),
        ),
        onWebViewCreated: (webController) {
          controller!.updateValue(
            controller!.value.copyWith(webViewController: AdaptiveWebviewController(webController)),
          );
          webController
            ..addJavaScriptHandler(
              handlerName: 'Ready',
              callback: _onReady,
            )
            ..addJavaScriptHandler(
              handlerName: 'StateChange',
              callback: _onStateChange,
            )
            ..addJavaScriptHandler(
              handlerName: 'PlaybackQualityChange',
              callback: _onPlaybackQualityChange,
            )
            ..addJavaScriptHandler(
              handlerName: 'PlaybackRateChange',
              callback: _onPlaybackRateChange,
            )
            ..addJavaScriptHandler(
              handlerName: 'Errors',
              callback: _onErrors,
            )
            ..addJavaScriptHandler(
              handlerName: 'VideoData',
              callback: _onVideoData,
            )
            ..addJavaScriptHandler(
              handlerName: 'VideoTime',
              callback: _onVideoTime,
            );
        },
        onLoadStop: (_, __) {
          _onLoadStopCalled = true;
          if (_isPlayerReady) {
            controller!.updateValue(
              controller!.value.copyWith(isReady: true),
            );
          }
        },
      ),
    );
  }

  Widget buildWindows(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Webview(
        webviewController,
        permissionRequested: _onPermissionRequested,
      ),
    );
  }

  String get player => '''
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            html,
            body {
                margin: 0;
                padding: 0;
                background-color: #000000;
                overflow: hidden;
                position: fixed;
                height: 100%;
                width: 100%;
                pointer-events: none;
            }
        </style>
        <meta name='viewport' content='width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no'>
    </head>
    <body>
        <div id="player"></div>
        <script>
            var tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            var firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
            var player;
            var timerId;
            function onYouTubeIframeAPIReady() {
                player = new YT.Player('player', {
                    height: '100%',
                    width: '100%',
                    videoId: '${controller!.initialVideoId}',
                    playerVars: {
                        'controls': 0,
                        'playsinline': 1,
                        'enablejsapi': 1,
                        'fs': 0,
                        'rel': 0,
                        'showinfo': 0,
                        'iv_load_policy': 3,
                        'modestbranding': 1,
                        'cc_load_policy': ${boolean(value: controller!.flags.enableCaption)},
                        'cc_lang_pref': '${controller!.flags.captionLanguage}',
                        'autoplay': ${boolean(value: controller!.flags.autoPlay)},
                        'start': ${controller!.flags.startAt},
                        'end': ${controller!.flags.endAt}
                    },
                    events: {
                        onReady: function(event) {
                          ${Platform.isWindows 
                          ? "window.chrome.webview.postMessage({'event': 'Ready'});" 
                          : "window.flutter_inappwebview.callHandler('Ready');"}
                        },
                        onStateChange: function(event) { sendPlayerStateChange(event.data); },
                        onPlaybackQualityChange: function(event) { 
                          ${Platform.isWindows 
                          ? "window.chrome.webview.postMessage({'event': 'PlaybackQualityChange', 'arg': [event.data]});" 
                          : "window.flutter_inappwebview.callHandler('PlaybackQualityChange', event.data);"}
                        },
                        onPlaybackRateChange: function(event) { 
                          ${Platform.isWindows 
                          ? "window.chrome.webview.postMessage({'event': 'PlaybackRateChange', 'arg': [event.data]});" 
                          : "window.flutter_inappwebview.callHandler('PlaybackRateChange', event.data);"}
                        },
                        onError: function(error) { 
                          ${Platform.isWindows 
                          ? "window.chrome.webview.postMessage({'event': 'Errors', 'arg': [error.data]});" 
                          : "window.flutter_inappwebview.callHandler('Errors', error.data);"}
                        }
                    },
                });
            }

            function sendPlayerStateChange(playerState) {
                clearTimeout(timerId);
                ${Platform.isWindows 
                ? "window.chrome.webview.postMessage({'event': 'StateChange', 'arg': [playerState]});" 
                : "window.flutter_inappwebview.callHandler('StateChange', playerState);"}
                if (playerState == 1) {
                    startSendCurrentTimeInterval();
                    sendVideoData(player);
                }
            }

            function sendVideoData(player) {
                var videoData = {
                    'duration': player.getDuration(),
                    'title': player.getVideoData().title,
                    'author': player.getVideoData().author,
                    'videoId': player.getVideoData().video_id
                };
                ${Platform.isWindows 
                ? "window.chrome.webview.postMessage({'event': 'VideoData', 'arg': [videoData]});" 
                : "window.flutter_inappwebview.callHandler('VideoData', videoData);"}
            }

            function startSendCurrentTimeInterval() {
                timerId = setInterval(function () {
                  ${Platform.isWindows 
                ? "window.chrome.webview.postMessage({'event': 'VideoTime', 'arg': [player.getCurrentTime(), player.getVideoLoadedFraction()]});" 
                : "window.flutter_inappwebview.callHandler('VideoTime', player.getCurrentTime(), player.getVideoLoadedFraction());"}
                }, 100);
            }

            function play() {
                player.playVideo();
                return '';
            }

            function pause() {
                player.pauseVideo();
                return '';
            }

            function loadById(loadSettings) {
                player.loadVideoById(loadSettings);
                return '';
            }

            function cueById(cueSettings) {
                player.cueVideoById(cueSettings);
                return '';
            }

            function loadPlaylist(playlist, index, startAt) {
                player.loadPlaylist(playlist, 'playlist', index, startAt);
                return '';
            }

            function cuePlaylist(playlist, index, startAt) {
                player.cuePlaylist(playlist, 'playlist', index, startAt);
                return '';
            }

            function mute() {
                player.mute();
                return '';
            }

            function unMute() {
                player.unMute();
                return '';
            }

            function setVolume(volume) {
                player.setVolume(volume);
                return '';
            }

            function seekTo(position, seekAhead) {
                player.seekTo(position, seekAhead);
                return '';
            }

            function setSize(width, height) {
                player.setSize(width, height);
                return '';
            }

            function setPlaybackRate(rate) {
                player.setPlaybackRate(rate);
                return '';
            }

            function setTopMargin(margin) {
                document.getElementById("player").style.marginTop = margin;
                return '';
            }
            
             function hideTopMenu() {
                try { document.querySelector('#player').contentDocument.querySelector('.ytp-chrome-top, .ytp-title, .ytp-show-cards-title, .ytp-title-channel-logo, .ytp-pause-overlay, .ytp-title-channel, .ytp-hide-info-bar, .ytp-hide-info-bar, .ytp-chrome-top-buttons').style.display = 'none'; } catch(e) { }
                return '';
            }
            
            function hideBottomMenu() {
                try { document.querySelector('#player').contentDocument.querySelector('.ytp-watermark').style.display = 'none'; } catch(e) { }
                return '';
            }
            
            function hidePauseOverlay() {
                try { document.querySelector('#player').contentDocument.querySelector('.ytp-pause-overlay').style.display = 'none'; } catch(e) { }
                return '';
            }
        </script>
    </body>
    </html>
  ''';

  String boolean({required bool value}) => value == true ? "'1'" : "'0'";

  String get userAgent => controller!.flags.forceHD
      ? 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/77.0.3865.90 Safari/537.36'
      : '';

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {
    final decision = await showDialog<WebviewPermissionDecision>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('WebView permission requested'),
        content: Text('WebView has requested permission \'$kind\''),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, WebviewPermissionDecision.deny),
            child: const Text('Deny'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, WebviewPermissionDecision.allow),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    return decision ?? WebviewPermissionDecision.none;
  }

  _onReady(List args) {
    _isPlayerReady = true;
    if (_onLoadStopCalled) {
      controller!.updateValue(
        controller!.value.copyWith(isReady: true),
      );
    }
  }

  _onStateChange(List args) {
    switch (args.first as int) {
      case -1:
        controller!.updateValue(
          controller!.value.copyWith(
            playerState: PlayerState.unStarted,
            isLoaded: true,
          ),
        );
        break;
      case 0:
        widget.onEnded?.call(controller!.metadata);
        controller!.updateValue(
          controller!.value.copyWith(
            playerState: PlayerState.ended,
          ),
        );
        break;
      case 1:
        controller!.updateValue(
          controller!.value.copyWith(
            playerState: PlayerState.playing,
            isPlaying: true,
            hasPlayed: true,
            errorCode: 0,
          ),
        );
        break;
      case 2:
        controller!.updateValue(
          controller!.value.copyWith(
            playerState: PlayerState.paused,
            isPlaying: false,
          ),
        );
        break;
      case 3:
        controller!.updateValue(
          controller!.value.copyWith(
            playerState: PlayerState.buffering,
          ),
        );
        break;
      case 5:
        controller!.updateValue(
          controller!.value.copyWith(
            playerState: PlayerState.cued,
          ),
        );
        break;
      default:
        throw Exception("Invalid player state obtained.");
    }
  }

  _onPlaybackQualityChange(List args) {
    controller!.updateValue(
      controller!.value.copyWith(playbackQuality: args.first as String),
    );
  }

  _onPlaybackRateChange(List args) {
    final num rate = args.first;
    controller!.updateValue(
      controller!.value.copyWith(playbackRate: rate.toDouble()),
    );
  }

  _onErrors(List args) {
    controller!.updateValue(
      controller!.value.copyWith(errorCode: args.first as int),
    );
  }

  _onVideoData(List args) {
    controller!.updateValue(
      controller!.value.copyWith(metaData: YoutubeMetaData.fromRawData(args.first)),
    );
  }

  _onVideoTime(List args) {
    final position = args.first * 1000;
    final num buffered = args.last;
    controller!.updateValue(
      controller!.value.copyWith(
        position: Duration(milliseconds: position.floor()),
        buffered: buffered.toDouble(),
      ),
    );
  }
}
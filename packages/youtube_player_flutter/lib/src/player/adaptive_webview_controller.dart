import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:webview_windows/webview_windows.dart';

/// Webview Controller for both mobile and desktop
class AdaptiveWebviewController {
  WebviewController? _webviewController;
  InAppWebViewController? _inAppWebViewController;

  /// Initialize from specific controller of each platform
  AdaptiveWebviewController(dynamic controller) {
    if (controller is WebviewController && Platform.isWindows) {
      _webviewController = controller;
      return;
    }

    if (controller is InAppWebViewController && (Platform.isAndroid || Platform.isIOS)) {
      _inAppWebViewController = controller;
      return;
    }
    throw UnsupportedError('UnsupportedError');
  }

  ///Evaluates JavaScript [source] code into the WebView and returns the result of the evaluation.
  Future<dynamic> evaluateJavascript({required String source}) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _inAppWebViewController!.evaluateJavascript(source: source);
    }
    if (Platform.isWindows) {
      return _webviewController!.executeScript(source);
    }
    throw UnsupportedError('UnsupportedError');
  }

  ///Reloads the WebView.
  Future<void> reload() {
    if (Platform.isAndroid || Platform.isIOS) {
      return _inAppWebViewController!.reload();
    }
    if (Platform.isWindows) {
      return _webviewController!.reload();
    }
    throw UnsupportedError('UnsupportedError');
  }
}

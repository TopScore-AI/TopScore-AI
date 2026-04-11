import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'desmos_platform_view.dart';

class DesmosPlatformMobile extends DesmosPlatformView {
  const DesmosPlatformMobile({super.key, required super.html});

  @override
  Widget build(BuildContext context) {
    // Note: In some setups, you might need to manage the controller lifecycle 
    // outside this stateless widget, but for a simple display this works 
    // or you can use a basic WebView wrapper here.
    return WebViewWidget(
      controller: WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadHtmlString(html),
    );
  }
}

DesmosPlatformView createPlatformView({Key? key, required String html}) =>
    DesmosPlatformMobile(key: key, html: html);

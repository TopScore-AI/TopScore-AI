import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'desmos_platform_view.dart';

class DesmosPlatformWeb extends DesmosPlatformView {
  const DesmosPlatformWeb({super.key, required super.html});

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (Object element) {
        // Safe cast to HTMLIFrameElement from package:web
        final iframe = element as web.HTMLIFrameElement;
        iframe.srcdoc = html.toJS;
        iframe.style.border = 'none';
        iframe.style.width = '100%';
        iframe.style.height = '100%';
      },
    );
  }
}

DesmosPlatformView createPlatformView({Key? key, required String html}) =>
    DesmosPlatformWeb(key: key, html: html);

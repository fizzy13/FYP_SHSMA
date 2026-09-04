import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class Go2rtcLiveView extends StatefulWidget {
  const Go2rtcLiveView({super.key, required this.url});

  final String url;

  @override
  State<Go2rtcLiveView> createState() => _Go2rtcLiveViewState();
}

class _Go2rtcLiveViewState extends State<Go2rtcLiveView> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'shsma-go2rtc-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (viewId) {
      return web.HTMLIFrameElement()
        ..src = widget.url
        ..title = 'Live camera feed'
        ..scrolling = 'no'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = '0'
        ..style.pointerEvents = 'none'
        ..style.overflow = 'hidden'
        ..style.display = 'block';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
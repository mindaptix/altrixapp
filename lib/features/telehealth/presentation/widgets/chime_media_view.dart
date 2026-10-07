import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../data/services/telehealth_permission_service.dart';

class ChimeMediaView extends StatefulWidget {
  const ChimeMediaView({
    super.key,
    this.chimeData,
    this.onConnected,
    this.onChanged,
  });
  final Map<String, dynamic>? chimeData;
  final VoidCallback? onConnected;
  final VoidCallback? onChanged;

  @override
  State<ChimeMediaView> createState() => ChimeMediaViewState();
}

class ChimeMediaViewState extends State<ChimeMediaView>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  Widget? _webView;
  String? _error;
  bool ready = false, muted = false, cameraOn = true;
  int _generation = 0;
  bool _suspended = false, _resumePreview = false;
  Completer<void>? _stopped;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final generation = ++_generation;
    try {
      final allowed =
          await TelehealthPermissionService.requestCameraAndMicrophone(context);
      if (!mounted || generation != _generation) return;
      if (!allowed) {
        setState(
          () => _error = 'Allow camera and microphone access to continue.',
        );
        return;
      }
      final sdk = await rootBundle.loadString('assets/telehealth/chime-sdk.js');
      final template = await rootBundle.loadString(
        'assets/telehealth/room.html',
      );
      if (!mounted || generation != _generation) return;
      PlatformWebViewControllerCreationParams params =
          const PlatformWebViewControllerCreationParams();
      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      }
      final controller = WebViewController.fromPlatformCreationParams(
        params,
        onPermissionRequest: (request) => request.grant(),
      );
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(const Color(0xFF020617));
      await controller.addJavaScriptChannel(
        'Telehealth',
        onMessageReceived: (message) {
          if (!mounted || generation != _generation) return;
          final event = jsonDecode(message.message) as Map<String, dynamic>;
          switch (event['type']) {
            case 'loaded':
              unawaited(
                controller.runJavaScript(
                  widget.chimeData == null
                      ? 'window.telehealth.preview();'
                      : 'window.telehealth.join(${jsonEncode(widget.chimeData)});',
                ),
              );
            case 'ready':
              setState(() {
                ready = true;
                _error = null;
              });
            case 'connected':
              widget.onConnected?.call();
            case 'left':
              if (_stopped?.isCompleted == false) _stopped!.complete();
            case 'mic':
              setState(() => muted = event['value'] == true);
              widget.onChanged?.call();
            case 'camera':
              setState(() => cameraOn = event['value'] == true);
              widget.onChanged?.call();
            case 'error':
              setState(() {
                ready = false;
                _error = event['value'] as String;
              });
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (_) => NavigationDecision.prevent,
        ),
      );
      if (controller.platform is AndroidWebViewController) {
        await (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      // An isolated HTTPS origin supplies the secure context required by WebRTC.
      await controller.loadHtmlString(
        template.replaceFirst('/*SDK*/', sdk),
        baseUrl: 'https://telehealth.altrix.invalid/',
      );
      if (!mounted || generation != _generation) return;
      PlatformWebViewWidgetCreationParams widgetParams =
          PlatformWebViewWidgetCreationParams(controller: controller.platform);
      if (controller.platform is AndroidWebViewController) {
        // Surface-backed hybrid composition avoids black WebRTC video frames
        // on several MediaTek/Mali devices when Flutter uses a texture layer.
        widgetParams =
            AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
              widgetParams,
              displayWithHybridComposition: true,
            );
      }
      setState(() {
        _controller = controller;
        _webView = WebViewWidget.fromPlatformCreationParams(
          params: widgetParams,
        );
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Unable to initialize video. Please retry.');
      }
    }
  }

  Future<void> command(String name) async {
    if (!ready) return;
    await _controller?.runJavaScript(
      'void window.telehealth.command(${jsonEncode(name)});',
    );
  }

  Future<void> stop() async {
    _suspended = true;
    ready = false;
    if (_controller == null) return;
    _stopped = Completer<void>();
    await _controller!.runJavaScript('void window.telehealth.leave();');
    await _stopped!.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
  }

  Future<void> restart() async {
    _suspended = false;
    if (_controller != null) {
      await _controller!.runJavaScript('window.telehealth.preview();');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.chimeData != null) return;
    if (state == AppLifecycleState.paused && !_suspended) {
      _resumePreview = true;
      unawaited(stop().catchError((_) {}));
    }
    if (state == AppLifecycleState.resumed && _resumePreview) {
      _resumePreview = false;
      unawaited(restart().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    ++_generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stop().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (_webView != null) Positioned.fill(child: _webView!),
      if (_controller == null && _error == null)
        const Center(child: CircularProgressIndicator()),
      if (_error != null)
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFF020617),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.chimeData == null)
                      TextButton(
                        onPressed: () async {
                          await stop();
                          if (!mounted) return;
                          setState(() {
                            _error = null;
                            _controller = null;
                            _webView = null;
                          });
                          await _initialize();
                        },
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

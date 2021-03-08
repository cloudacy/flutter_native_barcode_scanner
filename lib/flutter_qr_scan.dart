import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FlutterQrScanTexture {
  int id;

  double? width;
  double? height;

  FlutterQrScanTexture({
    required this.id,
    required this.width,
    required this.height,
  });
}

class FlutterQrScan {
  static const MethodChannel _channel = const MethodChannel('flutter_qr_scan');

  static StreamController<dynamic>? _controller;

  /// Creates a new code stream and tries to start the QR-code scan.
  ///
  /// May throw a `PlatformException`.
  static Future<FlutterQrScanTexture?> start() async {
    // Create a new StreamController to receive codes from the platform.
    // ignore: close_sinks
    final controller = StreamController<dynamic>();

    // Assign the new controller to the static variable.
    _controller = controller;

    // Add a method call handler to add received codes to the StreamController.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'code') {
        controller.add(call.arguments);
      }
    });

    // Invoke the "start" platform method and return the result.
    final result = await _channel.invokeMapMethod<String, dynamic>('start');
    if (result == null) {
      return null;
    }

    // Check the textureId.
    final textureId = result['textureId'];
    if (textureId == null || !(textureId is int)) {
      return null;
    }

    return FlutterQrScanTexture(
      id: textureId,
      width: (result['previewWidth'] as num?)?.toDouble(),
      height: (result['previewHeight'] as num?)?.toDouble(),
    );
  }

  /// Stops a currently running QR-code scan.
  static Future<bool> stop() async {
    // Check if a QR-code scan is running.
    final controller = _controller;
    if (controller == null) {
      return false;
    }

    // Close the stream controller, since we no receive any QR codes.
    controller.close();
    _controller = null;

    // Invoke the "stop" platform method.
    return (await _channel.invokeMethod<bool>('stop')) ?? false;
  }

  /// Returns the current QR-code scan code stream.
  ///
  /// Returns null of no QR-code scan is running.
  static Stream<dynamic>? getCodeStream() {
    return _controller?.stream;
  }
}

class FlutterQrScanPreview extends StatelessWidget {
  final FlutterQrScanTexture texture;

  const FlutterQrScanPreview({
    required this.texture,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: (texture.height ?? 1) / (texture.width ?? 1),
      child: Texture(textureId: texture.id),
    );
  }
}

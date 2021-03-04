import 'dart:async';

import 'package:flutter/services.dart';

class FlutterQrScanTexture {
  int id;

  double width;
  double height;

  FlutterQrScanTexture({
    required this.id,
    required this.width,
    required this.height,
  });
}

class FlutterQrScan {
  static const MethodChannel _channel = const MethodChannel('flutter_qr_scan');

  static StreamController<dynamic>? _controller;

  /// Creates a new code stream and starts the QR-code scan.
  static Future<Map<String, dynamic>?> start() {
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
    return _channel.invokeMapMethod<String, dynamic>('start');
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

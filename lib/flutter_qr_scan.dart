import 'dart:async';

import 'package:flutter/services.dart';

class FlutterQrScan {
  static const MethodChannel _channel = const MethodChannel('flutter_qr_scan');

  static StreamController<dynamic> _controller;

  static Future<Map<String, dynamic>> start() async {
    final Map<String, dynamic> result = await _channel.invokeMapMethod('start');
    return result;
  }

  static Future<bool> stop() async {
    // Close the stream controller, since we no longer expect any QR codes.
    _controller.close();
    _controller = null;

    // Send the "stop" method to the underlying platform.
    final bool result = await _channel.invokeMethod('stop');

    return result;
  }

  static Stream<dynamic> getCodeStream() {
    // Initialize the stream controller if not set yet.
    if (_controller == null) {
      _controller = StreamController<dynamic>();

      _channel.setMethodCallHandler((call) async {
        if (call.method == 'code') {
          _controller.add(call.arguments);
        }
      });
    }

    return _controller.stream;
  }
}

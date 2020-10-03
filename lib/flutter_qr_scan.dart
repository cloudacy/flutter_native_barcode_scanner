import 'dart:async';

import 'package:flutter/services.dart';

class FlutterQrScan {
  static const MethodChannel _channel = const MethodChannel('flutter_qr_scan');

  static Future<Map<String, dynamic>> start() async {
    final Map<String, dynamic> result = await _channel.invokeMapMethod('start');
    return result;
  }

  static Future<bool> stop() async {
    final bool result = await _channel.invokeMethod('stop');
    return result;
  }

  static void setListener(void Function(dynamic data) listener) {
    _channel.setMethodCallHandler((call) async {
      listener(call.arguments);
    });
  }
}

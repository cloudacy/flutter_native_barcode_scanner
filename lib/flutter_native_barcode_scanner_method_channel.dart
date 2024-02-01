import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_native_barcode_scanner_platform_interface.dart';

/// An implementation of [FlutterNativeBarcodeScannerPlatform] that uses method channels.
class MethodChannelFlutterNativeBarcodeScanner extends FlutterNativeBarcodeScannerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_native_barcode_scanner');

  @override
  void addBarcodeCallback(Future<Object?> Function(MethodCall call) cb) {
    methodChannel.setMethodCallHandler(cb);
  }

  @override
  Future<Map<String, Object?>?> start(Map<String, Object?> arguments) async {
    final result = await methodChannel.invokeMapMethod<String, Object?>('start', arguments);
    return result;
  }

  @override
  Future<bool?> stop() async {
    final result = await methodChannel.invokeMethod<bool>('stop');
    return result;
  }
}

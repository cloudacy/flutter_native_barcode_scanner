import 'package:flutter/services.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_native_barcode_scanner_method_channel.dart';

abstract class FlutterNativeBarcodeScannerPlatform extends PlatformInterface {
  /// Constructs a FlutterNativeBarcodeScannerPlatform.
  FlutterNativeBarcodeScannerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterNativeBarcodeScannerPlatform _instance = MethodChannelFlutterNativeBarcodeScanner();

  /// The default instance of [FlutterNativeBarcodeScannerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterNativeBarcodeScanner].
  static FlutterNativeBarcodeScannerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterNativeBarcodeScannerPlatform] when
  /// they register themselves.
  static set instance(FlutterNativeBarcodeScannerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  void addBarcodeCallback(Future<Object?> Function(MethodCall call) cb) {
    throw UnimplementedError('addBarcodeCallback() has not been implemented.');
  }

  Future<Map<String, Object?>?> start(Map<String, Object?> arguments) {
    throw UnimplementedError('start() has not been implemented.');
  }

  Future<bool?> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }
}

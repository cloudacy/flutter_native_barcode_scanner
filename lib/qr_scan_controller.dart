import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'utils.dart';
import 'qr_scan_camera.dart';

class QrScanControllerValue {
  bool isScanning = false;
  int textureId;

  int previewWidth;
  int previewHeight;

  get initialized {
    return textureId != null;
  }

  /// Returns `previewHeight / previewWidth`.
  ///
  /// Can only be called when [initialize] is done.
  double get aspectRatio => previewHeight / previewWidth;
}

class QrScanController extends ValueNotifier<QrScanControllerValue> {
  final QrScanCamera camera;
  final QrScanResolution resolution;
  final List<QrScanCodeFormat> formats;
  final void Function(dynamic value) onCode;

  QrScanController({
    @required this.camera,
    this.resolution = QrScanResolution.medium,
    this.formats = QrScanCodeFormat.values,
    @required this.onCode,
  }) : super(QrScanControllerValue());

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    print("got event " + call.method);
    switch (call.method) {
      case "code":
        print('Received code.');
        onCode(call.arguments);
        break;
      case 'cameraClosed':
        print('Camera closed.');
        break;
    }
  }

  /// Initializes the camera on the device.
  ///
  /// Throws a [QrScanException] if the initialization fails.
  Future<void> initialize() async {
    try {
      qrScanMethodChannel.setMethodCallHandler(_methodCallHandler);

      final Map<dynamic, dynamic> reply = await qrScanMethodChannel.invokeMethod(
        'initialize',
        <String, dynamic>{
          'cameraId': camera.id,
          'resolution': qrScanResolutions[resolution],
          'codeFormats': [QrScanCodeFormat.qr].map((format) => qrScanCodeFormats[format]),
        },
      );

      print('initialize reply');
      print(reply);

      value.textureId = reply['textureId'];
      value.previewWidth = reply['previewWidth'];
      value.previewHeight = reply['previewHeight'];
    } on PlatformException catch (e) {
      throw new QrScanException(e.code, e.message);
    }
  }

  /// Start a QR scan.
  ///
  /// Throws a [QrScanException] if the capture fails.
  Future<Null> startScanning() async {
    if (value.textureId == null) {
      throw new QrScanException('Not initialized.', 'startScanning was called on uninitialized QRReaderController');
    }

    if (value.isScanning) {
      throw new QrScanException('Already scanning.', 'startScanning was called when a recording is already started.');
    }

    try {
      await qrScanMethodChannel.invokeMethod(
        'startScanning',
        <String, dynamic>{'textureId': value.textureId},
      );
      value.isScanning = true;
    } on PlatformException catch (e) {
      throw new QrScanException(e.code, e.message);
    }
  }
}

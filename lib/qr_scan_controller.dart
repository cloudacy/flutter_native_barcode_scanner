import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'utils.dart';
import 'qr_scan_camera.dart';

class QrScanControllerValue {
  final bool isScanning;

  final int previewTextureId;
  final int previewWidth;
  final int previewHeight;

  const QrScanControllerValue({
    this.previewTextureId,
    this.previewWidth,
    this.previewHeight,
    this.isScanning = false,
  });

  get initialized {
    return previewTextureId != null;
  }

  /// Returns `previewHeight / previewWidth`.
  ///
  /// Can only be called when [initialize] is done.
  double get aspectRatio => previewHeight / previewWidth;

  /// Returns a copy of this QrScanControllerValue instance.
  /// Given arguments will be overwritten in the copied version.
  QrScanControllerValue copyWith({
    int previewTextureId,
    int previewWidth,
    int previewHeight,
    bool isScanning,
  }) =>
      QrScanControllerValue(
        previewTextureId: previewTextureId ?? this.previewTextureId,
        previewWidth: previewWidth ?? this.previewWidth,
        previewHeight: previewHeight ?? this.previewHeight,
        isScanning: isScanning ?? this.isScanning,
      );
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
        value = value.copyWith(isScanning: false);
        break;
      case 'cameraClosed':
        print('Camera closed.');
        value = value.copyWith(
          previewTextureId: null,
          isScanning: false,
        );
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
          'codeFormats': [QrScanCodeFormat.qr].map((format) => qrScanCodeFormats[format]).toList(),
        },
      );

      print('initialize reply');
      print(reply);

      value = value.copyWith(
        previewTextureId: reply['textureId'],
        previewWidth: reply['previewWidth'],
        previewHeight: reply['previewHeight'],
      );
    } on PlatformException catch (e) {
      throw QrScanException(e.code, e.message);
    }
  }

  /// Start a QR scan.
  ///
  /// Throws a [QrScanException] if the capture fails.
  Future<Null> startScanning() async {
    if (value.previewTextureId == null) {
      throw QrScanException('Not initialized.', 'startScanning was called on uninitialized QRReaderController');
    }

    if (value.isScanning) {
      throw QrScanException('Already scanning.', 'startScanning was called when a recording is already started.');
    }

    try {
      await qrScanMethodChannel.invokeMethod(
        'startScanning',
        <String, dynamic>{'textureId': value.previewTextureId},
      );

      value = value.copyWith(
        isScanning: true,
      );
    } on PlatformException catch (e) {
      throw QrScanException(e.code, e.message);
    }
  }
}

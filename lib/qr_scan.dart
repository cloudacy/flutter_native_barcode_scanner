// import 'dart:async';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final MethodChannel _channel = const MethodChannel('io.cloudacy.qr_scan');

class QrScan extends StatefulWidget {
  @override
  _QrScanState createState() => _QrScanState();

  /// Returns a list of available cameras.
  ///
  /// May throw a [QrScanException].
  static Future<List<QrScanCamera>> getCameras() async {
    try {
      final List<dynamic> cameras = await _channel.invokeMethod('availableCameras');
      print('cameras:');
      print(cameras);
      return cameras.map((dynamic camera) {
        return new QrScanCamera(
          id: camera['id'],
          lensDirection: _parseCameraLensDirection(camera['lensFacing']),
        );
      }).toList();
    } on PlatformException catch (e) {
      throw new QrScanException(e.code, e.message);
    }
  }
}

class _QrScanState extends State<QrScan> {
  bool running = false;
  int textureId;

  @override
  Widget build(BuildContext context) {
    return Text('not used yet.');
  }
}

enum CameraLensDirection { front, back, external }
enum CodeFormat { codabar, code39, code93, code128, ean8, ean13, itf, upca, upce, aztec, datamatrix, pdf417, qr }
enum ResolutionPreset { low, medium, high }

var _availableFormats = {
  CodeFormat.codabar: 'codabar', // Android only
  CodeFormat.code39: 'code39',
  CodeFormat.code93: 'code93',
  CodeFormat.code128: 'code128',
  CodeFormat.ean8: 'ean8',
  CodeFormat.ean13: 'ean13',
  CodeFormat.itf: 'itf', // itf-14 on iOS, should be changed to Interleaved2of5?
  CodeFormat.upca: 'upca', // Android only
  CodeFormat.upce: 'upce',
  CodeFormat.aztec: 'aztec',
  CodeFormat.datamatrix: 'datamatrix',
  CodeFormat.pdf417: 'pdf417',
  CodeFormat.qr: 'qr',
};

/// Returns the resolution preset as a String.
String serializeResolutionPreset(ResolutionPreset resolutionPreset) {
  switch (resolutionPreset) {
    case ResolutionPreset.high:
      return 'high';
    case ResolutionPreset.medium:
      return 'medium';
    case ResolutionPreset.low:
      return 'low';
  }
  throw new ArgumentError('Unknown ResolutionPreset value');
}

List<String> serializeCodeFormatsList(List<CodeFormat> formats) {
  List<String> list = [];

  for (var i = 0; i < formats.length; i++) {
    if (_availableFormats[formats[i]] != null) {
      //  this format exists in my list of available formats
      list.add(_availableFormats[formats[i]]);
    }
  }

  return list;
}

CameraLensDirection _parseCameraLensDirection(String string) {
  switch (string) {
    case 'front':
      return CameraLensDirection.front;
    case 'back':
      return CameraLensDirection.back;
    case 'external':
      return CameraLensDirection.external;
  }
  throw new ArgumentError('Unknown CameraLensDirection value');
}

/// This is thrown when the plugin reports an error.
class QrScanException implements Exception {
  String code;
  String message;

  QrScanException(this.code, this.message);

  @override
  String toString() => '$runtimeType($code, $message)';
}

// Build the UI texture view of the video data with textureId.
class QRReaderPreview extends StatelessWidget {
  final QRReaderController controller;

  const QRReaderPreview(this.controller);

  @override
  Widget build(BuildContext context) {
    print(controller._textureId);
    return controller.value.isInitialized ? new Texture(textureId: controller._textureId) : new Container();
  }
}

/// The state of a [QRReaderController].
class QRReaderValue {
  /// True after [QRReaderController.initialize] has completed successfully.
  final bool isInitialized;

  /// True when the camera is scanning.
  final bool isScanning;

  final String errorDescription;

  /// The size of the preview in pixels.
  ///
  /// Is `null` until  [isInitialized] is `true`.
  final Size previewSize;

  const QRReaderValue({
    this.isInitialized,
    this.errorDescription,
    this.previewSize,
    this.isScanning,
  });

  const QRReaderValue.uninitialized()
      : this(
          isInitialized: false,
          isScanning: false,
        );

  /// Convenience getter for `previewSize.height / previewSize.width`.
  ///
  /// Can only be called when [initialize] is done.
  double get aspectRatio => previewSize.height / previewSize.width;

  bool get hasError => errorDescription != null;

  QRReaderValue copyWith({
    bool isInitialized,
    bool isScanning,
    String errorDescription,
    Size previewSize,
  }) {
    return new QRReaderValue(
      isInitialized: isInitialized ?? this.isInitialized,
      errorDescription: errorDescription,
      previewSize: previewSize ?? this.previewSize,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class QRReaderController extends ValueNotifier<QRReaderValue> {
  final QrScanCamera description;
  final ResolutionPreset resolutionPreset;
  final Function onCode;
  final List<CodeFormat> codeFormats;

  int _textureId;
  bool _isDisposed = false;
  Completer<Null> _creatingCompleter;

  QRReaderController(this.description, this.resolutionPreset, this.codeFormats, this.onCode)
      : super(const QRReaderValue.uninitialized());

  /// Initializes the camera on the device.
  ///
  /// Throws a [QrScanException] if the initialization fails.
  Future<Null> initialize() async {
    if (_isDisposed) {
      return new Future<Null>.value(null);
    }
    try {
      _channel.setMethodCallHandler(_handleMethod);
      _creatingCompleter = new Completer<Null>();
      print('invoke initialize method.');
      print(<String, dynamic>{
        'cameraId': description.id,
        'resolutionPreset': serializeResolutionPreset(resolutionPreset),
        'codeFormats': serializeCodeFormatsList(codeFormats),
      });
      final Map<dynamic, dynamic> reply = await _channel.invokeMethod(
        'initialize',
        <String, dynamic>{
          'cameraId': description.id,
          'resolutionPreset': serializeResolutionPreset(resolutionPreset),
          'codeFormats': serializeCodeFormatsList(codeFormats),
        },
      );
      print('initialize reply');
      print(reply);
      _textureId = reply['textureId'];
      print(_textureId);
      print(reply['previewWidth']);
      print(reply['previewHeight']);
      value = value.copyWith(
        isInitialized: true,
        previewSize: new Size(
          reply['previewWidth'].toDouble(),
          reply['previewHeight'].toDouble(),
        ),
      );
    } on PlatformException catch (e) {
      throw new QrScanException(e.code, e.message);
    }
    _creatingCompleter.complete(null);
    return _creatingCompleter.future;
  }

  /// Start a QR scan.
  ///
  /// Throws a [QrScanException] if the capture fails.
  Future<Null> startScanning() async {
    if (!value.isInitialized || _isDisposed) {
      throw new QrScanException(
        'Uninitialized QRReaderController',
        'startScanning was called on uninitialized QRReaderController',
      );
    }
    if (value.isScanning) {
      throw new QrScanException(
        'A scan has already started.',
        'startScanning was called when a recording is already started.',
      );
    }
    try {
      value = value.copyWith(isScanning: true);
      await _channel.invokeMethod(
        'startScanning',
        <String, dynamic>{'textureId': _textureId},
      );
    } on PlatformException catch (e) {
      throw new QrScanException(e.code, e.message);
    }
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    print("got event " + call.method);
    switch (call.method) {
      case "code":
        // if (value.isScanning) {
        onCode(call.arguments);
        print("CODE HERE!");
        value = value.copyWith(isScanning: false);
        break;
      // }
      case 'cameraClosed':
        value = value.copyWith(isScanning: false);
        break;
    }
  }
}

class QrScanCamera {
  final String id;
  final CameraLensDirection lensDirection;

  QrScanCamera({this.id, this.lensDirection});

  @override
  bool operator ==(Object o) {
    return o is QrScanCamera && o.id == id && o.lensDirection == lensDirection;
  }

  @override
  int get hashCode {
    return hashValues(id, lensDirection);
  }

  @override
  String toString() {
    return '$runtimeType($id, $lensDirection)';
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';

/// Enum of available barcode formats, supported on iOS and Android.
///
/// - iOS: https://developer.apple.com/documentation/avfoundation/avmetadataobject/objecttype
/// - Android: https://developers.google.com/android/reference/com/google/mlkit/vision/barcode/common/Barcode.BarcodeFormat
enum FlutterNativeBarcodeFormat {
  aztec,
  code39,
  code93,
  code128,
  ean8,
  ean13,
  itf,
  pdf417,
  qr,
  upce,
}

const _barcodeFormatStringMap = {
  FlutterNativeBarcodeFormat.aztec: 'aztec',
  FlutterNativeBarcodeFormat.code39: 'code39',
  FlutterNativeBarcodeFormat.code93: 'code93',
  FlutterNativeBarcodeFormat.code128: 'code128',
  FlutterNativeBarcodeFormat.ean8: 'ean8',
  FlutterNativeBarcodeFormat.ean13: 'ean13',
  FlutterNativeBarcodeFormat.itf: 'itf',
  FlutterNativeBarcodeFormat.pdf417: 'pdf417',
  FlutterNativeBarcodeFormat.qr: 'qr',
  FlutterNativeBarcodeFormat.upce: 'upce',
};

/// The resulting object, when calling `FlutterNativeBarcodeScanner.start()`.
///
/// This object holds camera preview details: textureId for the `Texture` widget, texture `width` and `height` in pixels.
class FlutterNativeBarcodeScannerTexture {
  /// The id to be used at a `Texture` widget.
  /// ```dart
  /// Texture(textureId: texture.id)
  /// ```
  final int id;

  /// Holds the texture width in pixels. Can be null.
  final double? width;

  /// Holds the texture height in pixels. Can be null.
  final double? height;

  const FlutterNativeBarcodeScannerTexture._({
    required this.id,
    required this.width,
    required this.height,
  });
}

/// This class allows to start and stop the barcode scan process,
/// by using the static `start()` and `stop()` methods.
///
/// It also allows to receive barcodes, by calling `getCode()`.
class FlutterNativeBarcodeScanner {
  static const MethodChannel _channel = MethodChannel('flutter_native_barcode_scanner');

  static StreamController<Object?>? _controller;

  /// Creates a new code stream and tries to start the barcode scan.
  ///
  /// May throw a `PlatformException`.
  static Future<FlutterNativeBarcodeScannerTexture?> start({
    Size? scanFrame,
    List<FlutterNativeBarcodeFormat>? formats,
  }) async {
    // Create a new StreamController to receive codes from the platform.
    // ignore: close_sinks
    final controller = StreamController<Object?>();

    // Assign the new controller to the static variable.
    _controller = controller;

    // Add a method call handler to add received codes to the StreamController.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'code') {
        controller.add(call.arguments);
      }
    });

    // Invoke the "start" platform method and return the result.
    final result = await _channel.invokeMapMethod<String, Object?>('start', {
      if (scanFrame != null) 'scanFrame': [scanFrame.width, scanFrame.height],
      if (formats != null) 'formats': formats.map<String>((f) => _barcodeFormatStringMap[f] ?? '').toList(),
    });
    if (result == null) {
      return null;
    }

    // Check the textureId.
    final textureId = result['textureId'];
    if (textureId is! int) {
      return null;
    }

    return FlutterNativeBarcodeScannerTexture._(
      id: textureId,
      width: (result['previewWidth'] as num?)?.toDouble(),
      height: (result['previewHeight'] as num?)?.toDouble(),
    );
  }

  /// Stops a currently running barcode scan.
  static Future<bool> stop() async {
    // Check if a barcode scan is running.
    final controller = _controller;
    if (controller == null) {
      return false;
    }

    // Close the stream controller, since we no receive any barcodes.
    controller.close();
    _controller = null;

    // Invoke the "stop" platform method.
    return (await _channel.invokeMethod<bool>('stop')) ?? false;
  }

  /// Wait for a barcode to be returned by the platform.
  ///
  /// Returns `null` if no code got sent from the platform (e.g. the process got canceled)
  /// or if the barcode scan process is not running.
  static Future<Object?> getBarcode() {
    final stream = _controller?.stream;
    if (stream == null) {
      return Future.value(null);
    }

    try {
      return stream.first;
    } catch (_) {
      return Future.value(null);
    }
  }
}

/// [FlutterNativeBarcodeScannerPreview] provides an easy option to render a camera preview.
/// Provide an aspectRatio to optionally crop the preview to given aspect ratio.
class FlutterNativeBarcodeScannerPreview extends StatelessWidget {
  final FlutterNativeBarcodeScannerTexture _texture;

  /// Optional cropped aspect ratio. If set, the preview gets cropped to given aspect ratio.
  final double? aspectRatio;

  final Size? scanFrame;

  /// Create a new [FlutterNativeBarcodeScannerPreview] instance.
  ///
  /// Requires a [FlutterNativeBarcodeScannerTexture] to render the preview to the screen.
  ///
  /// Provide an optional `aspectRatio` to define a custom cropped preview aspect ratio.
  const FlutterNativeBarcodeScannerPreview({
    super.key,
    required FlutterNativeBarcodeScannerTexture texture,
    this.aspectRatio,
    this.scanFrame,
  }) : _texture = texture;

  @override
  Widget build(BuildContext context) {
    Widget child = Texture(textureId: _texture.id);

    if (scanFrame != null) {
      final oldChild = child;
      child = LayoutBuilder(
        builder: (context, box) {
          return Stack(
            children: [
              oldChild,
              Center(
                child: Container(
                  width: box.maxWidth * scanFrame!.width,
                  // on iOS a different resolution is used (1280x720), so we reduce the height
                  // to fit the resolution from android devices (640*480)
                  height: box.maxHeight * scanFrame!.height * (Platform.isIOS ? 0.75 : 1.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xffffff00)),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    if (aspectRatio == null) {
      return AspectRatio(
        aspectRatio: (_texture.height ?? 1) / (_texture.width ?? 1),
        child: child,
      );
    }

    final size = MediaQuery.of(context).size.width;
    return SizedBox(
      width: size,
      height: size / aspectRatio!,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            child: SizedBox(
              width: size,
              height: size / ((_texture.height ?? 1) / (_texture.width ?? 1)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

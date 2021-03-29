import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The resulting object, when calling `FlutterQrScan.start()`.
///
/// This object holds the textureId for the `Texture` widget as well as the
/// texture `width` and `height` in pixels.
///
/// The texture size properties `width` and `height` may be `null`. If so, we recommend to use an
/// `AspectRatio` widget with an aspectRatio of `1` instead.
class FlutterQrScanTexture {
  /// The id to be used at a `Texture` widget.
  /// ```dart
  /// Texture(textureId: texture.id)
  /// ```
  int id;

  /// Holds the texture width in pixels.
  ///
  /// If null, we recommend to use an aspect ratio of 1:1 instead.
  double? width;

  /// Holds the texture height in pixels.
  ///
  /// If null, we recommended to use an aspect ratio of 1:1 instead.
  double? height;

  FlutterQrScanTexture._({
    required this.id,
    required this.width,
    required this.height,
  });
}

/// This class allows to start and stop the QR-code scan process,
/// by using the static `start()` and `stop()` methods.
///
/// It also allows to receive QR-codes, by calling `getCode()`.
class FlutterQrScan {
  static const MethodChannel _channel = MethodChannel('flutter_qr_scan');

  static StreamController<Object?>? _controller;

  /// Creates a new code stream and tries to start the QR-code scan.
  ///
  /// May throw a `PlatformException`.
  static Future<FlutterQrScanTexture?> start() async {
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
    final result = await _channel.invokeMapMethod<String, Object?>('start');
    if (result == null) {
      return null;
    }

    // Check the textureId.
    final textureId = result['textureId'];
    if (!(textureId is int)) {
      return null;
    }

    return FlutterQrScanTexture._(
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

  /// Wait for a QR-code to be returned by the platform.
  ///
  /// Returns `null` if no code got sent from the platform (e.g. the process got canceled)
  /// or if the QR-code scan process is not running.
  static Future<Object?> getCode() {
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

/// `FlutterQrScanPreview` provides a quick option to render a QR-code scan texture, by using the `Texture` widget, to the screen.
///
/// It uses an `AspectRatio` widget with an aspectRatio, based on the `width` and `height` properties
/// of the provided `texture` argument.
class FlutterQrScanPreview extends StatelessWidget {
  final FlutterQrScanTexture _texture;

  /// Create a new `FlutterQrScanPreview` instance.
  ///
  /// Requires a `FlutterQrScanTexture` to draw a `Texture` to the screen, based on it's properties.
  const FlutterQrScanPreview({
    Key? key,
    required FlutterQrScanTexture texture,
  })   : _texture = texture,
        super(key: key);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: (_texture.height ?? 1) / (_texture.width ?? 1),
      child: Texture(textureId: _texture.id),
    );
  }
}

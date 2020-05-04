import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'utils.dart';
import 'controller.dart';
import 'camera.dart';

export 'utils.dart';
export 'controller.dart';
export 'camera.dart';

class FlutterQrScan extends StatefulWidget {
  /// Returns a list of available cameras.
  ///
  /// May throw a [QrScanException].
  static Future<List<QrScanCamera>> getCameras() async {
    try {
      final List<dynamic> cameras = await qrScanMethodChannel.invokeMethod('availableCameras');
      return cameras.map((dynamic camera) {
        return QrScanCamera(
          id: camera['id'],
          lensDirection: qrScanLensdirectionInv[camera['lensFacing']],
        );
      }).toList();
    } on PlatformException catch (e) {
      throw QrScanException(e.code, e.message);
    }
  }

  final QrScanController controller;

  FlutterQrScan({this.controller});

  @override
  _FlutterQrScanState createState() => _FlutterQrScanState();
}

class _FlutterQrScanState extends State<FlutterQrScan> {
  @override
  Widget build(BuildContext context) {
    if (!widget.controller.value.initialized) {
      return const Text('Not initialized.');
    }

    // Acutally call controller.startScanning() before this can work.
    // if (!widget.controller.value.isScanning) {
    //   return const Text('Not scanning.');
    // }

    return AspectRatio(
      aspectRatio: widget.controller.value.aspectRatio,
      child: Texture(textureId: widget.controller.value.previewTextureId),
    );
  }
}

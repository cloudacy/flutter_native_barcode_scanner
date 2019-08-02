import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'utils.dart';
import 'qr_scan_controller.dart';
import 'qr_scan_camera.dart';

export 'utils.dart';
export 'qr_scan_controller.dart';
export 'qr_scan_camera.dart';

class QrScan extends StatefulWidget {
  /// Returns a list of available cameras.
  ///
  /// May throw a [QrScanException].
  static Future<List<QrScanCamera>> getCameras() async {
    try {
      final List<dynamic> cameras = await qrScanMethodChannel.invokeMethod('availableCameras');
      print('cameras:');
      print(cameras);
      return cameras.map((dynamic camera) {
        return new QrScanCamera(
          id: camera['id'],
          lensDirection: qrScanLensdirectionInv[camera['lensFacing']],
        );
      }).toList();
    } on PlatformException catch (e) {
      throw new QrScanException(e.code, e.message);
    }
  }

  final QrScanController controller;

  QrScan({this.controller});

  @override
  _QrScanState createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  bool running = false;
  int textureId;

  @override
  Widget build(BuildContext context) {
    return widget.controller.value.textureId != null
        ? Texture(textureId: widget.controller.value.textureId)
        : Container();
  }
}

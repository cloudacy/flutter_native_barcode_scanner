import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_qr_scan/flutter_qr_scan.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int textureId;

  double previewWidth;
  double previewHeight;

  String barcodeData;

  @override
  void initState() {
    super.initState();

    _scanQRCode();
  }

  Future<void> _scanQRCode() async {
    // Start the QR Scan.
    final startResult = await FlutterQrScan.start();
    print('start: $startResult');

    // Set the textureId to the value, returned from the "start" function.
    setState(() {
      this.textureId = startResult['textureId'];
      this.previewWidth = (startResult['previewWidth'] as num).toDouble() ?? 1920;
      this.previewHeight = (startResult['previewHeight'] as num).toDouble() ?? 1080;
    });

    // Get the QR code stream.
    final codeStream = FlutterQrScan.getCodeStream();

    // Wait until the first QR code comes in.
    final data = await codeStream.first;

    // Set the barcode data and set textureId to null to stop the scan.
    setState(() {
      this.barcodeData = data;
      this.textureId = null;
    });

    // Stop the QR code scan process.
    final stopResult = await FlutterQrScan.stop();
    print('stop: $stopResult');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: Column(
            children: [
              if (textureId != null)
                AspectRatio(
                  aspectRatio: previewWidth / previewHeight,
                  child: Texture(textureId: textureId),
                ),
              if (barcodeData != null) Text(barcodeData)
            ],
          ),
        ),
      ),
    );
  }
}

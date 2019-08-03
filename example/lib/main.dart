import 'package:flutter/material.dart';

import 'package:qr_scan/qr_scan.dart';

List<QrScanCamera> cameras;

void logError(String code, String message) => print('Error: $code: $message');

Future<Null> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await QrScan.getCameras();
  } on QrScanException catch (e) {
    logError(e.code, e.message);
  }

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  QrScanController controller;

  @override
  void initState() {
    super.initState();

    // If no camera is available, abort here.
    if (cameras.isEmpty) {
      logError('QrScanNoCameraAvailable', 'No cameras available.');
      return;
    }

    // Create a new QrScanController and pass the selected camera to it.
    // Also add the onCode callback, which holds the value from detected barcodes.
    controller = QrScanController(
      camera: cameras[0],
      formats: [QrScanCodeFormat.qr],
      resolution: QrScanResolution.medium,
      onCode: onCode,
    );

    // Update the state, if the controller value changes.
    controller.addListener(() {
      print('update state');
      if (mounted) setState(() {});
    });

    // Initialize QrScan.
    try {
      print('initializing ...');
      controller.initialize();
    } on QrScanException catch (e) {
      logError(e.code, e.message);
    }
  }

  void onCode(dynamic value) {
    print('onCode');
    print(value);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: controller.value.initialized ? QrScan(controller: controller) : const Text('Please wait ...'),
        ),
      ),
    );
  }
}

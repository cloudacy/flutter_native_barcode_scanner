import 'package:flutter/material.dart';

import 'package:qr_scan/qr_scan.dart';

List<QrScanCamera> cameras;

Future<Null> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await QrScan.getCameras();
  } on QrScanException catch (e) {
    logError(e.code, e.message);
  }

  runApp(new MyApp());
}

void logError(String code, String message) => print('Error: $code\nError Message: $message');

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  QRReaderController controller;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();

    // Use the first camera in the list of available cameras.
    if (cameras.isNotEmpty) {
      onNewCameraSelected(cameras[0]);
    } else {
      print('No cameras available.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Stack(children: <Widget>[
            new Container(
              child: new Padding(
                padding: const EdgeInsets.all(0.0),
                child: new Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
            ),
          ])),
    );
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      return const Text(
        'No camera selected',
        style: const TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.w900,
        ),
      );
    } else {
      return new AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: new QRReaderPreview(controller),
      );
    }
  }

  void onCode(dynamic value) {
    print(value);
    //_scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(value.toString())));
    // ... do something
    // wait 5 seconds then start scanning again.
    // new Future.delayed(const Duration(seconds: 5), controller.startScanning);
  }

  void onNewCameraSelected(QrScanCamera cameraDescription) async {
    if (controller != null) {
      controller.dispose();
    }
    controller =
        new QRReaderController(cameraDescription, ResolutionPreset.low, [CodeFormat.qr, CodeFormat.pdf417], onCode);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      print('initializing ...');
      await controller.initialize();
    } on QrScanException catch (e) {
      logError(e.code, e.message);
      print('Error: ${e.code}\n${e.message}');
    }

    if (mounted) {
      setState(() {});
      // controller.startScanning();
    }
  }
}

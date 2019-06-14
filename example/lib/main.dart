import 'package:flutter/material.dart';

import 'package:qr_scan/qr_scan.dart';

// List<CameraDescription> cameras;

Future<Null> main() async {
  /*
  // Fetch the available cameras before initializing the app.
  try {
    cameras = await availableCameras();
  } on QRReaderException catch (e) {
    logError(e.code, e.description);
  }
  */
  runApp(new MyApp());
}

void logError(String code, String message) => print('Error: $code\nError Message: $message');

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

  /*
  // QRReaderController controller;
  AnimationController animationController;
  Animation<double> verticalPosition;

  @override
  void initState() {
    super.initState();

    animationController = new AnimationController(
      vsync: this,
      duration: new Duration(seconds: 3),
    );

    animationController.addListener(() {
      this.setState(() {});
    });
    animationController.forward();

    verticalPosition = Tween<double>(begin: 0.0, end: 300.0)
        .animate(CurvedAnimation(parent: animationController, curve: Curves.linear))
      ..addStatusListener((state) {
        if (state == AnimationStatus.completed) {
          animationController.reverse();
        } else if (state == AnimationStatus.dismissed) {
          animationController.forward();
        }
      });

    // pick the first available camera
    onNewCameraSelected(cameras[0]);

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
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
            Center(
              child: Stack(
                children: <Widget>[
                  SizedBox(
                    height: 300.0,
                    width: 300.0,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.red, width: 2.0)),
                    ),
                  ),
                  Positioned(
                    top: verticalPosition.value,
                    child: Container(
                      width: 300.0,
                      height: 2.0,
                      color: Colors.red,
                    ),
                  )
                ],
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
          color: Colors.white,
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

  void onCodeRead(dynamic value) {
    print(value.toString());
    // showInSnackBar(value.toString());
    // ... do something
    // wait 5 seconds then start scanning again.
    new Future.delayed(const Duration(seconds: 5), controller.startScanning);
  }

  void onNewCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller =
        new QRReaderController(cameraDescription, ResolutionPreset.low, [CodeFormat.qr, CodeFormat.pdf417], onCodeRead);

    // If the controller is updated then update the UI.
    controller.addListener(() {
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });

    try {
      await controller.initialize();
    } on QRReaderException catch (e) {
      logError(e.code, e.description);
      print('Error: ${e.code}\n${e.description}');
    }

    if (mounted) {
      setState(() {});
      controller.startScanning();
    }
  }
  */
}

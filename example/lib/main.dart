import 'package:flutter/material.dart';

import 'package:flutter_qr_scan/flutter_qr_scan.dart';

Future<Null> main() async {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  QrScanController controller;

  Future<List<QrScanCamera>> camerasFuture = FlutterQrScan.getCameras();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (controller != null) controller.dispose();
    super.dispose();
  }

  void initController(QrScanCamera camera) {
    // Create a new QrScanController and pass the selected camera to it.
    // Also add the onCode callback, which holds the value from detected barcodes.
    controller = QrScanController(
      camera: camera,
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
    print('initializing ...');
    controller.initialize();
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
        body: FutureBuilder(
          future: camerasFuture,
          builder: (BuildContext context, AsyncSnapshot<List<QrScanCamera>> data) {
            if (data.connectionState != ConnectionState.done) {
              return Center(child: CircularProgressIndicator());
            }

            if (data.hasError || !data.hasData) {
              return Center(
                child: const Text(
                  'Unable to fetch available cameras.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            }

            List<QrScanCamera> cameras = data.data;

            if (cameras.length == 0) {
              return Center(
                child: const Text(
                  'No cameras available.',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              );
            }

            if (controller == null) {
              initController(cameras[0]);
            }

            return Center(
              child: FlutterQrScan(controller: controller),
            );
          },
        ),
      ),
    );
  }
}

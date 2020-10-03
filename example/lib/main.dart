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
  String barcodeData;

  @override
  void initState() {
    super.initState();
    startCamera().then((value) {
      FlutterQrScan.setListener((data) {
        setState(() {
          this.barcodeData = data;
          this.textureId = null;
        });

        FlutterQrScan.stop();
      });
    });
  }

  Future<void> startCamera() async {
    try {
      final result = await FlutterQrScan.start();
      print('got: $result');
      // If the widget was removed from the tree while the asynchronous platform
      // message was in flight, we want to discard the reply rather than calling
      // setState to update our non-existent appearance.
      if (!mounted) return;

      setState(() {
        this.textureId = result['textureId'];
      });
    } catch (e) {
      print(e);
    }
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
                  aspectRatio: 1,
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

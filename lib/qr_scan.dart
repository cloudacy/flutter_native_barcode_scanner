import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class QrScan extends StatefulWidget {
  @override
  _QrScanState createState() => _QrScanState();
}

class _QrScanState extends State<QrScan> {
  static const MethodChannel _channel = const MethodChannel('io.cloudacy.qr_scan');

  @override
  void initState() {
    super.initState();
    prepareCamera();
  }

  void prepareCamera() async {
    final dynamic data = await _channel.invokeMapMethod('init');
    print(data);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        //Texture(textureId: null),
        RaisedButton(
          child: Text('start'),
          onPressed: () {
            _channel.invokeMethod('start');
          },
        ),
      ],
    );
  }
}

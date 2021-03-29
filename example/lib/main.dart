import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_qr_scan/flutter_qr_scan.dart';

void main() {
  runApp(MaterialApp(home: FlutterQrScanExample()));
}

class FlutterQrScanExample extends StatefulWidget {
  @override
  _FlutterQrScanExampleState createState() => _FlutterQrScanExampleState();
}

class _FlutterQrScanExampleState extends State<FlutterQrScanExample> {
  final _textureStream = StreamController<FlutterQrScanTexture>();
  final _codeStream = StreamController<Object?>();

  @override
  void initState() {
    super.initState();

    _scanQRCode();
  }

  Future<void> _showErrorDialog({
    required Widget content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('An error occurred.'),
          content: content,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _scanQRCode() async {
    try {
      // Start the QR-code scan.
      final texture = await FlutterQrScan.start();
      if (texture == null) {
        _showErrorDialog(content: const Text('Unable to start the QR-code scan.'));

        // Stop the QR-code scan process.
        await FlutterQrScan.stop();
        return;
      }

      // Add the returned texture to the textureStream.
      _textureStream.add(texture);

      // Wait for a code.
      final code = await FlutterQrScan.getCode();
      if (code == null) {
        _showErrorDialog(content: const Text('Unable to get a QR-code.'));

        // Stop the QR-code scan process.
        await FlutterQrScan.stop();
        return;
      }

      // Add the code to the _codeStream.
      _codeStream.add(code);
    } catch (e) {
      _showErrorDialog(content: Text('Error: $e'));
    } finally {
      // Stop the QR-code scan process.
      await FlutterQrScan.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR-code scan example'),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: StreamBuilder<FlutterQrScanTexture>(
                  stream: _textureStream.stream,
                  builder: (context, snapshot) {
                    final texture = snapshot.data;
                    if (texture == null) {
                      return const CircularProgressIndicator();
                    }

                    return FlutterQrScanPreview(texture: texture);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: StreamBuilder<Object?>(
                stream: _codeStream.stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.active) {
                    return const Text('waiting for code ...');
                  }

                  final code = snapshot.data;
                  if (code == null) {
                    return const Text('waiting for code ...');
                  }

                  return Text(code.toString());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

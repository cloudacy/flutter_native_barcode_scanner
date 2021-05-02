import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_barcode_scanner/flutter_native_barcode_scanner.dart';

void main() {
  runApp(MaterialApp(home: FlutterNativeBarcodeScannerExample()));
}

class FlutterNativeBarcodeScannerExample extends StatefulWidget {
  @override
  _FlutterNativeBarcodeScannerExampleState createState() => _FlutterNativeBarcodeScannerExampleState();
}

class _FlutterNativeBarcodeScannerExampleState extends State<FlutterNativeBarcodeScannerExample> {
  final _textureStream = StreamController<FlutterNativeBarcodeScannerTexture>();
  final _codeStream = StreamController<Object?>();

  @override
  void initState() {
    super.initState();

    _scanBarcode();
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

  Future<void> _scanBarcode() async {
    try {
      // Start the barcode scan.
      final texture = await FlutterNativeBarcodeScanner.start();
      if (texture == null) {
        _showErrorDialog(content: const Text('Unable to start the barcode scan.'));

        // Stop the barcode scan process.
        await FlutterNativeBarcodeScanner.stop();
        return;
      }

      // Add the returned texture to the textureStream.
      _textureStream.add(texture);

      // Wait for a code.
      final code = await FlutterNativeBarcodeScanner.getBarcode();
      if (code == null) {
        _showErrorDialog(content: const Text('Unable to get a barcode.'));

        // Stop the barcode scan process.
        await FlutterNativeBarcodeScanner.stop();
        return;
      }

      // Add the code to the _codeStream.
      _codeStream.add(code);
    } catch (e) {
      _showErrorDialog(content: Text('Error: $e'));
    } finally {
      // Stop the barcode scan process.
      await FlutterNativeBarcodeScanner.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('barcode scan example'),
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: StreamBuilder<FlutterNativeBarcodeScannerTexture>(
                  stream: _textureStream.stream,
                  builder: (context, snapshot) {
                    final texture = snapshot.data;
                    if (texture == null) {
                      return const CircularProgressIndicator();
                    }

                    return FlutterNativeBarcodeScannerPreview(texture: texture);
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

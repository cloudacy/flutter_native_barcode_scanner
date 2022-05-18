import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_barcode_scanner/flutter_native_barcode_scanner.dart';

void main() {
  runApp(const MaterialApp(home: FlutterNativeBarcodeScannerExample()));
}

class FlutterNativeBarcodeScannerExample extends StatefulWidget {
  const FlutterNativeBarcodeScannerExample({
    Key? key,
  }) : super(key: key);

  @override
  State<FlutterNativeBarcodeScannerExample> createState() => _FlutterNativeBarcodeScannerExampleState();
}

class _FlutterNativeBarcodeScannerExampleState extends State<FlutterNativeBarcodeScannerExample> {
  final _texture = ValueNotifier<FlutterNativeBarcodeScannerTexture?>(null);
  final _code = ValueNotifier<Object?>(null);

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
      final texture = await FlutterNativeBarcodeScanner.start(
        formats: [
          FlutterNativeBarcodeFormat.ean8,
          FlutterNativeBarcodeFormat.ean13,
        ],
      );
      if (texture == null) {
        _showErrorDialog(content: const Text('Unable to start the barcode scan.'));

        // Stop the barcode scan process.
        await FlutterNativeBarcodeScanner.stop();
        return;
      }

      // Add the returned texture to the textureStream.
      _texture.value = texture;

      // Wait for a code.
      final code = await FlutterNativeBarcodeScanner.getBarcode();
      if (code == null) {
        _showErrorDialog(content: const Text('Unable to get a barcode.'));

        // Stop the barcode scan process.
        await FlutterNativeBarcodeScanner.stop();
        return;
      }

      // Add the code to the _codeStream.
      _code.value = code;
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
        actions: [
          ValueListenableBuilder<Object?>(
            valueListenable: _code,
            builder: (context, code, _) {
              if (code == null) return const SizedBox(width: 0);

              return IconButton(
                onPressed: () {
                  _texture.value = null;
                  _code.value = null;

                  _scanBarcode();
                },
                icon: const Icon(Icons.replay_outlined),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: ValueListenableBuilder<FlutterNativeBarcodeScannerTexture?>(
                valueListenable: _texture,
                builder: (context, texture, _) {
                  if (texture == null) {
                    return const CircularProgressIndicator();
                  }

                  return FlutterNativeBarcodeScannerPreview(texture: texture);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ValueListenableBuilder<Object?>(
                valueListenable: _code,
                builder: (context, code, _) {
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

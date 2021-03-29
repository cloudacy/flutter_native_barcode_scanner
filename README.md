# flutter_qr_scan

A lightweight QR-code scan plugin for flutter.

⚠️ This package is still in beta stage! ⚠️

## Example

```dart
class FlutterQrScanExample extends StatefulWidget {
  @override
  _FlutterQrScanExampleState createState() => _FlutterQrScanExampleState();
}

class _FlutterQrScanExampleState extends State<FlutterQrScanExample> {
  final _textureStream = StreamController<FlutterQrScanTexture>();

  @override
  void initState() {
    super.initState();

    _scanQRCode();
  }

  Future<void> _scanQRCode() async {
    try {
      // Start the QR-code scan.
      final texture = await FlutterQrScan.start();
      if (texture == null) {
        // Handle error.
        return;
      }

      // Add the returned texture to the textureStream.
      _textureStream.add(texture);

      // Get the QR code stream.
      final codeStream = FlutterQrScan.getCodeStream();
      if (codeStream == null) {
        // Handle error.
        return;
      }

      // Wait until the first QR code comes in.
      final code = await codeStream.first;

      // Process code ...

      // Stop the QR-code scan process.
      await FlutterQrScan.stop();
    } catch (e) {
      // Handle error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('QR-code scan example')),
      body: Center(
        child: StreamBuilder<FlutterQrScanTexture>(
          stream: _textureStream.stream,
          builder: (context, snapshot) {
            final texture = snapshot.data;
            if (texture == null) {
              return CircularProgressIndicator();
            }

            return FlutterQrScanPreview(texture: texture);
          },
        ),
      ),
    );
  }
}
```

## Installation

### Android

Add the barcode ML model to the `<projcet-root>/android/app/src/main/AndroidManifest.xml` file of the app.
https://firebase.google.com/docs/ml-kit/android/read-barcodes

```xml
<application ...>
  ...
  <meta-data android:name="com.google.firebase.ml.vision.DEPENDENCIES" android:value="barcode" />
  <!-- To use multiple models: android:value="barcode,model2,model3" -->
</application>
```

### iOS

**This plugin supports iOS 10.0 or higher.**

Make sure that the `NSCameraUsageDescription` (or `Privacy - Camera Usage Description`) string is set at `ios/Runner/info.plist` to scan codes.

```xml
<key>NSCameraUsageDescription</key>
<string>...</string>
```

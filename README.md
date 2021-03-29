# flutter_qr_scan

A lightweight Flutter QR-code scan plugin for android and iOS.

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
        // Handle error...

        // Stop the QR-code scan process.
        await FlutterQrScan.stop();
        return;
      }

      // Add the returned texture to the textureStream.
      _textureStream.add(texture);

      // Wait until the first QR code comes in.
      final code = await FlutterQrScan.getCode();
      if (code == null) {
        // Handle error...

        // Stop the QR-code scan process.
        await FlutterQrScan.stop();
        return;
      }

      // Process code ...
    } catch (e) {
      // Handle error...
    } finally {
      // Stop the QR-code scan process.
      await FlutterQrScan.stop();
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

**This plugin supports Android 5.0 ("Lollipop", SDK 21) or higher.**

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

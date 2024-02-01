# flutter_native_barcode_scanner

A barcode scanner for Flutter, using platform native APIs.

⚠️ This package is still in beta stage! ⚠️

## Example

```dart
class FlutterNativeBarcodeScannerExample extends StatefulWidget {
  @override
  _FlutterNativeBarcodeScannerExampleState createState() => _FlutterNativeBarcodeScannerExampleState();
}

class _FlutterNativeBarcodeScannerExampleState extends State<FlutterNativeBarcodeScannerExample> {
  final _textureStream = StreamController<FlutterNativeBarcodeScannerTexture>();

  @override
  void initState() {
    super.initState();

    _scanBarcode();
  }

  Future<void> _scanBarcode() async {
    try {
      // Start the barcode scan.
      final texture = await FlutterNativeBarcodeScanner.start();
      if (texture == null) {
        // Handle error...

        // Stop the barcode scan process.
        await FlutterNativeBarcodeScanner.stop();
        return;
      }

      // Add the returned texture to the textureStream.
      _textureStream.add(texture);

      // Wait until the first barcode comes in.
      final code = await FlutterNativeBarcodeScanner.getBarcode();
      if (code == null) {
        // Handle error...

        // Stop the barcode scan process.
        await FlutterNativeBarcodeScanner.stop();
        return;
      }

      // Process code ...
    } catch (e) {
      // Handle error...
    } finally {
      // Stop the barcode scan process.
      await FlutterNativeBarcodeScanner.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('barcode scan example')),
      body: Center(
        child: StreamBuilder<FlutterNativeBarcodeScannerTexture>(
          stream: _textureStream.stream,
          builder: (context, snapshot) {
            final texture = snapshot.data;
            if (texture == null) {
              return CircularProgressIndicator();
            }

            return FlutterNativeBarcodeScannerPreview(texture: texture);
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

**This plugin supports iOS 12.0 or higher.**

Make sure that the `NSCameraUsageDescription` (or `Privacy - Camera Usage Description`) string is set at `ios/Runner/info.plist` to scan codes.

```xml
<key>NSCameraUsageDescription</key>
<string>...</string>
```

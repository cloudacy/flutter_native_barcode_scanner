# flutter-qr-scan

A lightweight QR-code scanning plugin for flutter.

## Development links
- https://flutter.dev/docs/development/packages-and-plugins/developing-packages
- https://flutter.dev/docs/development/platform-integration/platform-channels

- https://github.com/flutter/plugins/tree/master/packages/camera

### iOS specific
- https://developer.apple.com/documentation/coreimage/ciqrcodefeature
- https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture/capturing_still_and_live_photos

### Android specific

Add the barcode ML model to the AndroidManifest.xml file of the app.
https://firebase.google.com/docs/ml-kit/android/read-barcodes

```xml
<application ...>
  ...
  <meta-data android:name="com.google.firebase.ml.vision.DEPENDENCIES" android:value="barcode" />
  <!-- To use multiple models: android:value="barcode,model2,model3" -->
</application>
```
